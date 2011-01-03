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
    end

    def node=(node)
      self.position = node ? node.position : nil
      @node = node
    end
  end

  class SyntaxError < NodeError
  end

  class InternalCompilerError < NodeError
    attr_accessor :node

    def initialize(ex_or_string)
      if ex_or_string.kind_of?(Exception)
        node = ex_or_string.node if ex_or_string.respond_to?(:node)
        super(ex_or_string.message, node)
        self.cause = ex_or_string
        self.position ||= cause.position if cause.respond_to?(:position)
        set_backtrace(cause.backtrace)
      else
        super(ex_or_string)
      end
    end

    def self.wrap(ex, node)
      if ex.kind_of?(NodeError)
        ex.node ||= node
      elsif ex.kind_of?(MirahError)
        ex.position ||= node.position
      else
        ex = new(ex)
        ex.node ||= node
      end
      ex
    end
  end
end