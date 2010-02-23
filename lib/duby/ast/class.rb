module Duby::AST
  class ClassDefinition < Node
    include Annotated
    include Named
    include Scope
    attr_accessor :interfaces

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

    def define_constructor(position, *args)
      append_node(_define_method(
          ConstructorDefinition, position, 'initialize', nil, args))
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
              signature[arg_name.intern] = type
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

    def infer(typer)
      unless resolved?
        @inferred_type ||= typer.define_type(name, superclass, @interfaces) do
          if body
            typer.infer(body)
          else
            typer.no_type
          end
        end
        if @inferred_type
          resolved!
        else
          typer.defer(self)
        end
      end

      @inferred_type
    end

    def implements(*types)
      raise ArgumentError if types.any? {|x| x.nil?}
      @interfaces.concat types
    end
  end

  defmacro('implements') do |transformer, fcall, parent|
    interfaces = fcall.args_node.child_nodes.map do |interface|
      interface.type_reference(parent)
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

  defmacro('interface') do |transformer, fcall, parent|
    raise "Interface name required" unless fcall.args_node
    interfaces = fcall.args_node.child_nodes.to_a
    interface_name = interfaces.shift
    if (JRubyAst::CallNode === interface_name &&
        interface_name.args_node.size == 1)
      interfaces.unshift(interface_name.args_node.get(0))
      interface_name = interface_name.receiver_node
    end
    raise 'Interface body required' unless fcall.iter_node
    InterfaceDeclaration.new(parent, fcall.position,
                             interface_name.name,
                             transformer.annotations) do |interface|
      [interfaces.map {|p| p.type_reference(interface)},
       if fcall.iter_node.body_node
         transformer.transform(fcall.iter_node.body_node, interface)
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
          typer.learn_field_type(scope, name, @inferred_type)
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
        @inferred_type = typer.learn_field_type(scope, name, typer.infer(value))

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
        @inferred_type = typer.field_type(scope, name)

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end
end