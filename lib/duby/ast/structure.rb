module Duby::AST
  class Body < Node
    def initialize(parent, line_number)
      super(parent, line_number)
      @children = yield(self)
    end
        
    # Type of a block is the type of its final element
    def infer(typer)
      unless @inferred_type
        if children.size == 0
          @inferred_type = typer.default_type
        else
          children.each {|child| @inferred_type = typer.infer(child)}
        end
          
        unless @inferred_type
          typer.defer(self)
        end
      end

      @inferred_type
    end
  end
  
  class Noop < Node
    def infer(typer)
      @inferred_type ||= typer.no_type
    end
  end
  
  class Script < Node
    include Scope
    attr_accessor :body
    
    def initialize(parent, line_number)
      @body = (children = yield(self))[0]
      super(parent, line_number, children)
    end
    
    def infer(typer)
      @inferred_type ||= typer.infer(body) || (typer.defer(self); nil)
    end
  end
end