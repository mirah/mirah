module Duby::AST
  class LocalDeclaration < Node
    include Named
    include Typed
    include Scoped

    child :type

    def initialize(parent, line_number, name, captured=false, &block)
      super(parent, line_number, &block)
      @name = name
      @captured = captured
      # record the current scope for captured variables so it's preserved
      # after the block gets transformed into a class.
      scope if captured?
    end

    def captured?
      @captured
    end

    def infer(typer)
      resolve_if(typer) {typer.known_types[type] || type}
    end

    def resolved!(typer)
      typer.learn_local_type(scope, name, @inferred_type)
      super
    end
  end

  class LocalAssignment < Node
    include Named
    include Valued
    include Scoped

    child :value

    def initialize(parent, line_number, name, captured=false, &block)
      super(parent, line_number, &block)
      @captured = captured
      @name = name
      # record the current scope for captured variables so it's preserved
      # after the block gets transformed into a class.
      scope if captured?
    end

    def captured?
      @captured
    end

    def to_s
      "LocalAssignment(name = #{name}, scope = #{scope}, captured = #{captured?})"
    end

    def infer(typer)
      resolve_if(typer) {typer.infer(value)}
    end

    def resolved!(typer)
      typer.learn_local_type(scope, name, @inferred_type)
      super
    end
  end

  class Local < Node
    include Named
    include Scoped

    def initialize(parent, line_number, name, captured=false)
      super(parent, line_number, [])
      @name = name
      @captured = captured
      # record the current scope for captured variables so it's preserved
      # after the block gets transformed into a class.
      scope if captured?
    end

    def captured?
      @captured
    end

    def to_s
      "Local(name = #{name}, scope = #{scope}, captured = #{captured?})"
    end

    def infer(typer)
      unless @inferred_type
        @inferred_type = typer.local_type(scope, name)

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end
end