module Duby::AST
  class PrintLine < Node
    attr_accessor :parameters
    
    def initialize(parent, line_number)
      @parameters = children = yield(self)
      super(parent, line_number, children)
    end

    def infer(typer)
      resolved = parameters.select {|param| param.infer(typer); param.resolved?}
      resolved! if resolved.size == parameters.size
      typer.no_type
    end
  end
end