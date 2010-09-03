module Duby::AST
  class Arguments < Node
    child :args
    child :opt_args
    child :rest_arg
    child :args2
    child :block_arg

    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
    end

    def infer(typer)
      unless resolved?
        @inferred_type = args ? args.map {|arg| typer.infer(arg)} : []
        if @inferred_type.all?
          resolved!
        else
          typer.defer(self)
        end
      end
      @inferred_type
    end
  end

  class Argument < Node
    include Typed

    def resolved!(typer)
      typer.learn_local_type(containing_scope, name, @inferred_type)
      super
    end
  end

  class RequiredArgument < Argument
    include Named
    include Scoped

    def initialize(parent, line_number, name)
      super(parent, line_number)

      @name = name
    end

    def infer(typer)
      resolve_if(typer) do
        scope.static_scope << name
        # if not already typed, check parent of parent (MethodDefinition)
        # for signature info
        method_def = parent.parent
        signature = method_def.signature

        # if signature, search for this argument
        signature[name.intern] || typer.local_type(scope, name)
      end
    end
  end

  class OptionalArgument < Argument
    include Named
    include Scoped
    child :child

    def initialize(parent, line_number, name, &block)
      super(parent, line_number, &block)
      @name = name
    end

    def infer(typer)
      resolve_if(typer) do
        scope.static_scope << name
        # if not already typed, check parent of parent (MethodDefinition)
        # for signature info
        method_def = parent.parent
        signature = method_def.signature

        signature[name.intern] = child.infer(typer)
      end
    end
  end

  class RestArgument < Argument
    include Named
    include Scoped

    def initialize(parent, line_number, name)
      super(parent, line_number)

      @name = name
    end

    def infer(typer)
      scope.static_scope << name
      super
    end
  end

  class BlockArgument < Argument
    include Named
    include Scoped
    attr_accessor :optional
    alias optional? optional

    def initialize(parent, line_number, name)
      super(parent, line_number)

      @name = name
    end

    def infer(typer)
      scope.static_scope << name
      super
    end
  end

  class MethodDefinition < Node
    include Annotated
    include Named
    include Scope
    include Scoped
    include ClassScoped
    include Binding

    child :signature
    child :arguments
    child :body

    attr_accessor :defining_class
    attr_accessor :visibility

    def initialize(parent, line_number, name, annotations=[], &block)
      @annotations = annotations
      super(parent, line_number, &block)
      @name = name
      @visibility = (class_scope && class_scope.current_access_level) || :public
    end

    def name
      super
    end

    def infer(typer)
      resolve_if(typer) do
        @defining_class ||= begin
          static_scope.self_type = if static?
            scope.static_scope.self_type.meta
          else
            scope.static_scope.self_type
          end
        end
        typer.infer(arguments)
        typer.infer_signature(self)
        forced_type = signature[:return]
        inferred_type = body ? typer.infer(body) : typer.no_type

        if inferred_type && arguments.inferred_type.all?
          actual_type = if forced_type.nil?
            inferred_type
          else
            forced_type
          end
          if actual_type.unreachable?
            actual_type = typer.no_type
          end

          if !abstract? &&
              forced_type != typer.no_type &&
              !actual_type.is_parent(inferred_type)
            raise Duby::Typer::InferenceError.new(
                "Inferred return type %s is incompatible with declared %s" %
                [inferred_type, actual_type], self)
          end

          signature[:return] = actual_type
        end
      end
    end

    def resolve_if(typer)
      super(typer) do
        type = yield
        if type
          argument_types = arguments.inferred_type
          argument_types ||= [Duby::AST.error_type] if type.error?
          typer.learn_method_type(defining_class, name, argument_types, type, signature[:throws])

          # learn the other overloads as well
          args_for_opt = []
          if arguments.args
            arguments.args.each do |arg|
              if OptionalArgument === arg
                arg_types_for_opt = args_for_opt.map do |arg_for_opt|
                  arg_for_opt.infer(typer)
                end
                typer.learn_method_type(defining_class, name, arg_types_for_opt, type, signature[:throws])
              end
              args_for_opt << arg
            end
          end
        end
        type
      end
    end

    def abstract?
      InterfaceDeclaration === scope
    end

    def static?
      scope.static_scope.self_type.meta?
    end
  end

  class StaticMethodDefinition < MethodDefinition
    def static?
      true
    end
  end

  class ConstructorDefinition < MethodDefinition
    attr_accessor :delegate_args, :calls_super

    def initialize(*args)
      super
      extract_delegate_constructor
    end

    def first_node
      if body.kind_of? Body
        body.children[0]
      else
        body
      end
    end

    def first_node=(new_node)
      if body.kind_of? Body
        new_node.parent = body
        body.children[0] = new_node
      else
        self.body = new_node
      end
    end

    def extract_delegate_constructor
      # TODO verify that this constructor exists during type inference.
      possible_delegate = first_node
      if FunctionalCall === possible_delegate &&
          possible_delegate.name == 'initialize'
        @delegate_args = possible_delegate.parameters
      elsif Super === possible_delegate
        @calls_super = true
        @delegate_args = possible_delegate.parameters
        unless @delegate_args
          args = arguments.children.map {|x| x || []}
          @delegate_args = args.flatten.map do |arg|
            Local.new(self, possible_delegate.position, arg.name)
          end
        end
      end
      self.first_node = Noop.new(self, position) if @delegate_args
    end

    def infer(typer)
      unless @inferred_type
        delegate_args.each {|a| typer.infer(a)} if delegate_args
      end
      super
    end
  end
end
