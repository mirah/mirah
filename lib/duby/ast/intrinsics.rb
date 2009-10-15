module Duby::AST
  class PrintLine < Node
    attr_accessor :parameters
    
    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
      @parameters = children
    end

    def infer(typer)
      resolved = parameters.select {|param| typer.infer(param); param.resolved?}
      resolved! if resolved.size == parameters.size
      typer.no_type
    end
  end
  
  defmacro('puts') do |transformer, fcall, parent|
    PrintLine.new(parent, fcall.position) do |println|
      if fcall.args_node
        fcall.args_node.child_nodes.map do |arg|
          transformer.transform(arg, println)
        end
      else
        []
      end
    end
  end
end