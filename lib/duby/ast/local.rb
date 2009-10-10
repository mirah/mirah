module Duby::AST
  class LocalDeclaration < Node
    include Named
    include Typed
    include Scoped

    def initialize(parent, line_number, name, &block)
      super(parent, line_number, &block)
      @name = name
      @type = children[0]
    end

    def infer(typer)
      unless resolved?
        resolved!
        @inferred_type = typer.known_types[type] || type
        if @inferred_type
          resolved!
          typer.learn_local_type(scope, name, @inferred_type)
        else
          typer.defer(self)
        end
      end
      @inferred_type
    end
  end
  
  class LocalAssignment < Node
    include Named
    include Valued
    include Scoped
    
    def initialize(parent, line_number, name, &block)
      super(parent, line_number, children, &block)
      @value = children[0]
      @name = name
    end

    def to_s
      "LocalAssignment(name = #{name}, scope = #{scope})"
    end
    
    def infer(typer)
      unless @inferred_type
        @inferred_type = typer.learn_local_type(scope, name, typer.infer(value))

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end

  class Local < Node
    include Named
    include Scoped
    
    def initialize(parent, line_number, name)
      super(parent, line_number, [])
      @name = name
    end

    def to_s
      "Local(name = #{name}, scope = #{scope})"
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