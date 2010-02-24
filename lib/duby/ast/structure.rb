module Duby::AST
  class Body < Node
    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
    end

    # Type of a block is the type of its final element
    def infer(typer)
      unless @inferred_type
        if children.size == 0
          @inferred_type = typer.default_type
        else
          children.each {|child| @inferred_type = typer.infer(child)}
        end

        if @inferred_type
          resolved!
        else
          typer.defer(self)
        end
      end

      @inferred_type
    end
  end

  class Block < Node
    include Scoped
    child :args
    child :body

    def initialize(parent, position, &block)
      super(parent, position, &block)
    end

    def prepare(typer, method)
      duby = typer.transformer
      interface = method.argument_types[-1]
      outer_class = scope.defining_class
      name = "#{outer_class.name}$#{duby.tmp}"
      klass = duby.define_class(position, name)
      klass.interfaces = [interface]
      klass.define_constructor(position)
      impl_methods = find_methods(interface)
      # TODO: find a nice way to closure-impl multiple methods
      # perhaps something like
      # Collections.sort(list) do
      #   def equals(other); self == other; end
      #   def compareTo(x,y); Comparable(x).compareTo(y); end
      # end
      raise "Multiple abstract methods found; cannot use block" if impl_methods.size > 1
      impl_methods.each do |method|
        klass.define_method(position,
                            method.name,
                            method.actual_return_type,
                            args.dup).body = body.dup
      end
      call = parent
      instance = Call.new(call, position, 'new')
      instance.target = Constant.new(call, position, name)
      instance.parameters = []
      call.parameters << instance
      typer.infer(klass)
      typer.infer(instance)
    end

    def find_methods(interface)
      methods = []
      interfaces = [interface]
      until interfaces.empty?
        interface = interfaces.pop
        methods += interface.declared_instance_methods.select {|m| m.abstract?}
        interfaces.concat(interface.interfaces)
      end
      methods
    end
  end

  class Noop < Node
    def infer(typer)
      resolved!
      @inferred_type ||= typer.no_type
    end
  end

  class Script < Node
    include Scope
    child :body
    
    attr_accessor :defining_class

    def initialize(parent, line_number, &block)
      super(parent, line_number, children, &block)
    end

    def infer(typer)
      @defining_class ||= typer.self_type
      @inferred_type ||= typer.infer(body) || (typer.defer(self); nil)
    end
  end
end