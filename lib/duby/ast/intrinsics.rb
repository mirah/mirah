module Duby::AST
  defmacro('puts') do |transformer, fcall, parent|
    Call.new(parent, fcall.position, "println") do |x|
      args = if fcall.respond_to?(:args_node) && fcall.args_node
        fcall.args_node.child_nodes.map do |arg|
          transformer.transform(arg, x)
        end
      else
        []
      end
      [
        Call.new(x, fcall.position, "out") do |y|
          [
            Constant.new(y, fcall.position, "System"),
            []
          ]
        end,
        args,
        nil
      ]
    end
  end

  defmacro('print') do |transformer, fcall, parent|
    Call.new(parent, fcall.position, "print") do |x|
      args = if fcall.respond_to?(:args_node) && fcall.args_node
        fcall.args_node.child_nodes.map do |arg|
          transformer.transform(arg, x)
        end
      else
        []
      end
      [
        Call.new(x, fcall.position, "out") do |y|
          [
            Constant.new(y, fcall.position, "System"),
            []
          ]
        end,
        args,
        nil
      ]
    end
  end

  class InlineCode
    def initialize(&block)
      @block = block
    end

    def inline(transformer, call)
      @block.call(transformer, call)
    end
  end
end