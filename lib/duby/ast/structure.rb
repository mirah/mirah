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
    
    def initialize(parent, line_number, &block)
      super(parent, line_number, children, &block)
      @body = children[0]
    end
    
    def infer(typer)
      @inferred_type ||= typer.infer(body) || (typer.defer(self); nil)
    end
  end
end