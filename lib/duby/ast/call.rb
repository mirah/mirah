require 'delegate'

module Duby::AST
  class NodeProxy < DelegateClass(Node)
    def __inline__(node)
      node.parent = parent
      __setobj__(node)
    end
  end

  class FunctionalCall < Node
    include Named
    attr_accessor :parameters, :block, :cast, :inlined, :proxy
    alias cast? cast

    def self.new(*args, &block)
      real_node = super
      real_node.proxy = NodeProxy.new(real_node)
    end

    def initialize(parent, line_number, name, &kids)
      super(parent, line_number, &kids)
      @parameters, @block = children
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
        
        parameter_types << Duby::AST.block_type if @block
      
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
          if @block
            method = receiver_type.get_method(name, parameter_types)
            @block.prepare(typer, method)
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
    attr_accessor :target, :parameters, :block, :inlined, :proxy

    def self.new(*args, &block)
      real_node = super
      real_node.proxy = NodeProxy.new(real_node)
    end

    def initialize(parent, line_number, name, &kids)
      super(parent, line_number, children, &kids)
      @target, @parameters, @block = children
      @name = name
    end

    def infer(typer)
      unless @inferred_type
        receiver_type = typer.infer(target)
        should_defer = receiver_type.nil?
        parameter_types = parameters.map do |param|
          typer.infer(param) || should_defer = true
        end

        parameter_types << Duby::AST.block_type if @block

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
          if @block
            method = receiver_type.get_method(name, parameter_types)
            @block.prepare(typer, method)
          end
          resolved!
        else
          typer.defer(proxy)
        end
      end

      @inferred_type
    end
  end
end