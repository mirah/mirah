module Duby::AST
  class LocalDeclaration < Node
    include Named
    include Typed
    include Scoped

    child :type_node
    attr_accessor :type

    def initialize(parent, line_number, name, &block)
      super(parent, line_number, &block)
      @name = name
    end

    def captured?
      scope.static_scope.captured?(name)
    end

    def infer(typer)
      resolve_if(typer) do
        scope.static_scope << name
        @type = type_node.type_reference(typer)
      end
    end

    def resolved!(typer)
      typer.learn_local_type(containing_scope, name, @inferred_type)
      super
    end
  end

  class LocalAssignment < Node
    include Named
    include Valued
    include Scoped

    child :value

    def initialize(parent, line_number, name, &block)
      super(parent, line_number, &block)
      @name = name
    end

    def captured?
      scope.static_scope.captured?(name)
    end

    def to_s
      "LocalAssignment(name = #{name}, scope = #{scope}, captured = #{captured? == true})"
    end

    def infer(typer)
      resolve_if(typer) do
        scope.static_scope << name
        typer.infer(value)
      end
    end

    def resolved!(typer)
      typer.learn_local_type(containing_scope, name, @inferred_type)
      super
    end
  end

  class Local < Node
    include Named
    include Scoped

    def initialize(parent, line_number, name)
      super(parent, line_number, [])
      @name = name
    end

    def captured?
      scope.static_scope.captured?(name)
    end

    def to_s
      "Local(name = #{name}, scope = #{scope}, captured = #{captured? == true})"
    end

    def infer(typer)
      resolve_if(typer) do
        scope.static_scope << name
        typer.local_type(containing_scope, name)
      end
    end
  end
end