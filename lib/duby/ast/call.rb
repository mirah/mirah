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
  end

  class FunctionalCall < Node
    include Named
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

    def infer(typer)
      @self_type ||= typer.self_type

      unless @inferred_type
        receiver_type = @self_type
        should_defer = false

        parameter_types = parameters.map do |param|
          typer.infer(param) || should_defer = true
        end

        parameter_types << Duby::AST.block_type if block

        unless should_defer
          if parameters.size == 1 && typer.known_types[name]
            # cast operation
            resolved!
            self.cast = true
            @inferred_type = typer.known_types[name]
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
          resolved!
        else
          typer.defer(proxy)
        end
      end

      @inferred_type
    end
  end

  class Call < Node
    include Named
    attr_accessor :inlined, :proxy

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
      @self_type ||= typer.self_type.superclass

      unless @inferred_type
        receiver_type = @call_parent.defining_class
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