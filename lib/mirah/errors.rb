module Mirah
  class MirahError < StandardError
    attr_accessor :position
    attr_accessor :cause

    def initialize(message, position=nil)
      super(message)
      @position = node
    end
  end

  class NodeError < MirahError
    attr_reader :node

    def initialize(message, node=nil)
      position = node.position if node
      super(message, position)
      @node = node
    end

    def node=(node)
      @position = node ? node.position : nil
      @node = node
    end

    def self.wrap(ex, node)
      if ex.kind_of?(NodeError)
        ex.node ||= node
        return ex
      elsif ex.kind_of?(MirahError)
        ex.position ||= node.position
        return ex
      else
        new_ex = new(ex.message, node)
        new_ex.cause = ex
        new_ex.position ||= ex.position if ex.respond_to?(:position)
        new_ex.set_backtrace(ex.backtrace)
        return new_ex
      end
    end

    def position
      if node && node.position
        node.position
      else
        super
      end
    end
  end

  class SyntaxError < NodeError
  end


  class InferenceError < NodeError
  end

  class InternalCompilerError < NodeError
  end
end