module Duby::AST
  class ClassDefinition < Node
    include Annotated
    include Named
    include Scope
    attr_accessor :interfaces
    attr_accessor :current_access_level

    child :superclass
    child :body

    def initialize(parent, position, name, annotations=[], &block)
      @annotations = annotations
      @interfaces = []
      @name = name
      if Duby::AST.type_factory.respond_to? :declare_type
        Duby::AST.type_factory.declare_type(self)
      end
      # We need somewhere to collect nodes that get appended during
      # the transform phase.
      @extra_body = Body.new(self, position)
      super(parent, position, &block)
      if body
        @extra_body.insert(0, body)
      end
      self.body = @extra_body
    end

    def append_node(node)
      @extra_body << node
      node
    end

    def define_inner_class(position, name, &block)
      name = "#{self.name}$#{name}"
      append_node ClassDefinition.new(nil, position, name, &block)
    end

    def define_method(position, name, type, *args)
      append_node(_define_method(MethodDefinition, position, name, type, args))
    end

    def define_static_method(position, name, type, *args)
      append_node(
          _define_method(StaticMethodDefinition, position, name, type, args))
    end

    def define_constructor(position, *args, &block)
      append_node(_define_method(
          ConstructorDefinition, position, 'initialize', nil, args, &block))
    end

    def _define_method(klass, position, name, type, args)
      klass.new(nil, position, name) do |method|
        signature = {:return => type}
        if Arguments === args[0]
          args_node = args[0]
          args_node.parent = method
        else
          args_node = Arguments.new(method, position) do |args_node|
            arg_list = args.map do |arg_name, arg_type, arg_position|
              signature[arg_name.intern] = arg_type
              arg_position ||= position
              RequiredArgument.new(args_node, arg_position, arg_name)
            end
            [arg_list, nil, nil, nil]
          end
        end
        [
          signature,
          args_node,
          if block_given?
            yield(method)
          end
        ]
      end
    end

    def declare_field(position, name, type)
      field = FieldDeclaration.new(nil, position || self.position, name)
      field.type = type.dup
      append_node(field)
    end

    def infer(typer)
      resolve_if(typer) do
        typer.define_type(name, superclass, @interfaces) do
          static_scope.self_type = typer.self_type
          typer.infer(body) if body
        end
      end
    end

    def implements(*types)
      raise ArgumentError if types.any? {|x| x.nil?}
      @interfaces.concat types
    end
  end

  defmacro('implements') do |transformer, fcall, parent|
    interfaces = fcall.parameters.map do |interface|
      interface.type_reference
    end
    klass = parent
    klass = klass.parent unless ClassDefinition === klass
    klass.implements(*interfaces)
    Noop.new(parent, fcall.position)
  end

  class InterfaceDeclaration < ClassDefinition
    attr_accessor :superclass
    child :interfaces
    child :body

    def initialize(parent, position, name, annotations)
      super(parent, position, name, annotations) {|p| }
      @name = name
      @children = [[], nil]
      @children = yield(self)
    end
  end

  class ClosureDefinition < ClassDefinition
    attr_accessor :enclosing_type
    def initialize(parent, position, name, enclosing_type)
      super(parent, position, name, []) do
        [nil, nil]
      end
      @enclosing_type = enclosing_type
    end
  end

  defmacro('interface') do |transformer, fcall, parent|
    raise "Interface name required" unless fcall.parameters.size > 0
    interfaces = fcall.parameters
    interface_name = interfaces.shift
    if (Call === interface_name &&
        interface_name.parameters.size == 1)
      interfaces.unshift(interface_name.parameters[0])
      interface_name = interface_name.target
    end
    raise 'Interface body required' unless fcall.block
    InterfaceDeclaration.new(parent, fcall.position,
                             interface_name.name,
                             transformer.annotations) do |interface|
      [interfaces.map {|p| p.type_reference },
       if fcall.block.body
         fcall.block.body.parent = interface
         fcall.block.body
       end
      ]
    end
  end

  class FieldDeclaration < Node
    include Annotated
    include Named
    include ClassScoped
    include Typed

    child :type

    def initialize(parent, position, name, annotations=[], &block)
      @annotations = annotations
      super(parent, position, &block)
      @name = name
    end

    def infer(typer)
      unless resolved?
        resolved!
        @inferred_type = typer.known_types[type]
        if @inferred_type
          resolved!
          typer.learn_field_type(class_scope, name, @inferred_type)
        else
          typer.defer(self)
        end
      end
      @inferred_type
    end
  end

  class FieldAssignment < Node
    include Annotated
    include Named
    include Valued
    include ClassScoped

    child :value

    def initialize(parent, position, name, annotations=[], &block)
      @annotations = annotations
      super(parent, position, &block)
      @name = name
    end

    def infer(typer)
      unless resolved?
        @inferred_type = typer.learn_field_type(class_scope, name, typer.infer(value))

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end

  class Field < Node
    include Annotated
    include Named
    include ClassScoped

    def initialize(parent, position, name, annotations=[], &block)
      @annotations = annotations
      super(parent, position, &block)
      @name = name
    end

    def infer(typer)
      unless resolved?
        @inferred_type = typer.field_type(class_scope, name)

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end

  class AccessLevel < Node
    include ClassScoped
    include Named

    def initialize(parent, line_number, name)
      super(parent, line_number)
      @name = name
      class_scope.current_access_level = name.to_sym
    end

    def infer(typer)
      typer.no_type
    end
  end

  class Include < Node
    include Scoped

    def infer(typer)
      children.each do |type|
        the_scope = scope.static_scope
        the_scope.self_type = the_scope.self_type.include(type)
      end
    end

    def compile(compiler, expression); end
  end

  defmacro("include") do |transformer, fcall, parent|
    raise "Included Class name required" unless fcall.parameters.size > 0
    types = fcall.parameters.map do |const|
      const.type_reference
    end
    Include.new(parent, fcall.position, types)
  end
end
