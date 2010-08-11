require 'delegate'

module Duby::AST
  class NodeProxy < DelegateClass(Node)
    def __inline__(node)
      node.parent = parent
      __setobj__(node)
    end

    def dup
      new = super
      new.__setobj__(__getobj__.dup)
      new.proxy = new
      new
    end

    def _dump(depth)
      Marshal.dump(__getobj__)
    end

    def self._load(str)
      proxy = NodeProxy.new(Marshal.load(str))
      proxy.proxy = proxy
    end
  end

  class FunctionalCall < Node
    include Java::DubyLangCompiler.Call
    include Named
    include Scoped
    attr_accessor :cast, :inlined, :proxy
    alias cast? cast

    child :parameters
    child :block

    def self.new(*args, &block)
      real_node = super
      real_node.proxy = NodeProxy.new(real_node)
    end

    def initialize(parent, line_number, name, &kids)
      super(parent, line_number, &kids)
      @name = name
      @cast = false
    end

    def arguments
      @arguments ||= begin
        args = java.util.ArrayList.new(parameters.size)
        parameters.each do |param|
          args.add(param)
        end
        args
      end
    end

    def target
      nil
    end

    def infer(typer)
      unless @inferred_type
        @self_type ||= scope.static_scope.self_type
        receiver_type = @self_type
        should_defer = false

        parameter_types = parameters.map do |param|
          typer.infer(param) || should_defer = true
        end

        parameter_types << Duby::AST.block_type if block

        unless should_defer
          if parameters.size == 1 && typer.known_type(name)
            # cast operation
            resolved!
            self.cast = true
            @inferred_type = typer.known_type(name)
          elsif parameters.size == 0 && scope.static_scope.include?(name)
            @inlined = Local.new(parent, position, name)
            proxy.__inline__(@inlined)
            return proxy.infer(typer)
          else
            @inferred_type = typer.method_type(receiver_type, name,
                                               parameter_types)
            if @inferred_type.kind_of? InlineCode
              @inlined = @inferred_type.inline(typer.transformer, self)
              proxy.__inline__(@inlined)
              return proxy.infer(typer)
            end
          end
        end

        if @inferred_type
          if block
            method = receiver_type.get_method(name, parameter_types)
            block.prepare(typer, method)
          end
          @inferred_type = receiver_type if @inferred_type.void?
          resolved!
        else
          typer.defer(proxy)
        end
      end

      @inferred_type
    end
  end

  class Call < Node
    include Java::DubyLangCompiler.Call
    include Named
    attr_accessor :cast, :inlined, :proxy
    alias cast? cast

    child :target
    child :parameters
    child :block

    def self.new(*args, &block)
      real_node = super
      real_node.proxy = NodeProxy.new(real_node)
    end

    def initialize(parent, line_number, name, &kids)
      super(parent, line_number, &kids)
      @name = name
    end

    def arguments
      @arguments ||= begin
        args = java.util.ArrayList.new(parameters.size)
        parameters.each do |param|
          args.add(param)
        end
        args
      end
    end

    def infer(typer)
      unless @inferred_type
        receiver_type = typer.infer(target)
        should_defer = receiver_type.nil?
        parameter_types = parameters.map do |param|
          typer.infer(param) || should_defer = true
        end

        parameter_types << Duby::AST.block_type if block

        unless should_defer
          @inferred_type = typer.method_type(receiver_type, name,
                                             parameter_types)
          if @inferred_type.kind_of? InlineCode
            @inlined = @inferred_type.inline(typer.transformer, self)
            proxy.__inline__(@inlined)
            return proxy.infer(typer)
          end
        end

        if @inferred_type
          if block && !receiver_type.error?
            method = receiver_type.get_method(name, parameter_types)
            block.prepare(typer, method)
          end
          @inferred_type = receiver_type if @inferred_type.void?
          resolved!
        else
          typer.defer(proxy)
        end
      end

      @inferred_type
    end
  end

  class Super < Node
    include Named
    include Scoped
    attr_accessor :method, :cast
    alias :cast? :cast

    child :parameters

    def initialize(parent, line_number)
      super(parent, line_number)
      @call_parent = parent
      @call_parent = (@call_parent = @call_parent.parent) until MethodDefinition === @call_parent
      @cast = false
    end

    def name
      @call_parent.name
    end

    def infer(typer)
      @self_type ||= scope.static_scope.self_type.superclass

      unless @inferred_type
        receiver_type = @call_parent.defining_class.superclass
        should_defer = receiver_type.nil?
        parameter_types = parameters.map do |param|
          typer.infer(param) || should_defer = true
        end

        unless should_defer
          @inferred_type = typer.method_type(receiver_type, name,
                                             parameter_types)
        end

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end
end