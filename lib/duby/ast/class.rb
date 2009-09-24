module Duby::AST
  class ClassDefinition < Node
    include Named
    attr_accessor :superclass, :body, :interfaces
        
    def initialize(parent, line_number, name)
      super(parent, line_number)
      @interfaces = []
      @name = name
      @children = yield(self)
      @superclass, @body = children
    end
    
    def infer(typer)
      unless resolved?
        superclass = Duby::AST::type(@superclass.name) if @superclass
        @inferred_type ||= typer.define_type(name, superclass, @interfaces) do
          body.infer(typer)
        end
        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
    
    def implements(*types)
      @interfaces.concat types
    end
  end

  class FieldDeclaration < Node
    include Named
    include ClassScoped
    include Typed

    def initialize(parent, line_number, name)
      super(parent, line_number, yield(self))
      @name = name
      @type = children[0]
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
    include Named
    include Valued
    include ClassScoped
        
    def initialize(parent, line_number, name)
      super(parent, line_number, yield(self))
      @value = children[0]
      @name = name
    end

    def infer(typer)
      unless resolved?
        @inferred_type = typer.learn_field_type(scope, name, value.infer(typer))

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end
      
  class Field < Node
    include Named
    include ClassScoped
    
    def initialize(parent, line_number, name)
      super(parent, line_number)
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