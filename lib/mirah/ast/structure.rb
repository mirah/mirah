module Duby::AST
  class Body < Node
    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
    end

    # Type of a block is the type of its final element
    def infer(typer)
      unless @inferred_type
        @typer ||= typer
        @self_type ||= typer.self_type
        if children.size == 0
          @inferred_type = typer.no_type
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

    def <<(node)
      super
      if @typer
        orig_self = @typer.self_type
        @typer.known_types['self'] = @self_type
        @typer.infer(node)
        @typer.known_types['self'] = orig_self
      end
      self
    end
  end

  # class << self
  class ClassAppendSelf < Body
    include Scope
    include Scoped

    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
    end

    def infer(typer)
      static_scope.self_type = scope.static_scope.self_type.meta
      super
    end
  end

  class ScopedBody < Body
    include Scope
    include Scoped

    def infer(typer)
      static_scope.self_type ||= typer.self_type
      super
    end

    def inspect_children(indent=0)
      indent_str = ' ' * indent
      str = ''
      if static_scope.self_node
        str << "\n#{indent_str}self:\n" << static_scope.self_node.inspect(indent + 1)
      end
      str << "\n#{indent_str}body:" << super(indent + 1)
    end
  end

  class Block < Node
    include Scoped
    include Scope
    include Java::DubyLangCompiler::Block
    child :args
    child :body

    def initialize(parent, position, &block)
      super(parent, position) do
        static_scope.parent = scope.static_scope
        yield(self) if block_given?
      end
    end

    def prepare(typer, method)
      duby = typer.transformer
      interface = method.argument_types[-1]
      outer_class = scope.defining_class
      binding = scope.binding_type(duby)
      name = "#{outer_class.name}$#{duby.tmp}"
      klass = duby.define_closure(position, name, outer_class)
      klass.interfaces = [interface]
      klass.define_constructor(position,
                               ['binding', binding]) do |c|
          duby.eval("@binding = binding", '-', c, 'binding')
      end

      # TODO We need a special scope here that allows access to the
      # outer class.
      static_scope.self_type = typer.infer(klass)

      add_methods(klass, binding, typer)

      call = parent
      instance = Call.new(call, position, 'new')
      instance.target = Constant.new(call, position, name)
      instance.parameters = [
        BindingReference.new(instance, position, binding)
      ]
      call.parameters << instance
      call.block = nil
      typer.infer(instance)
    end

    def add_methods(klass, binding, typer)
      found_def = false
      body.each do |node|
        if node.kind_of?(MethodDefinition)
          found_def = true
          node.static_scope = static_scope
          node.binding_type = binding
          klass.append_node(node)
        end
      end
      build_method(klass, binding, typer) unless found_def
    end

    def build_method(klass, binding, typer)
      # find all methods which would not otherwise be on java.lang.Object
      impl_methods = find_methods(klass.interfaces).select do |m|
        begin
          obj_m = java.lang.Object.java_class.java_method m.name, *m.parameter_types
        rescue NameError
          # not found on Object
          next true
        end
        # found on Object
        next false
      end

      raise "Multiple abstract methods found; cannot use block" if impl_methods.size > 1
      impl_methods.each do |method|
        mdef = klass.define_method(position,
                                   method.name,
                                   method.return_type,
                                   args.dup)
        mdef.static_scope = static_scope
        mdef.body = body.dup
        mdef.binding_type = binding
        typer.infer(mdef.body)
      end
    end

    def find_methods(interfaces)
      methods = []
      interfaces = interfaces.dup
      until interfaces.empty?
        interface = interfaces.pop
        methods += interface.declared_instance_methods.select {|m| m.abstract?}
        interfaces.concat(interface.interfaces)
      end
      methods
    end
  end

  class BindingReference < Node
    def initialize(parent, position, type)
      super(parent, position)
      @inferred_type = type
    end

    def infer(typer)
      resolved! unless resolved?
      @inferred_type
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
    include Binding
    child :body

    attr_accessor :defining_class
    attr_reader :filename

    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
      @package = ""
    end

    def infer(typer)
      resolve_if(typer) do
        typer.set_filename(self, filename)
        @defining_class ||= begin
          static_scope.self_type = typer.self_type
        end
        typer.infer(body)
      end
    end

    def filename=(filename)
      @filename = filename
      package = File.dirname(@filename).tr('/', '.')
      package.sub! /^\.+/, ''
      static_scope.package = package
    end
  end
end
