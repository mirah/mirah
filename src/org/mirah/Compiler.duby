import org.jrubyparser.SourcePosition

class ParseError
  def initialize(message:String, position:SourcePosition)
    @message = message
    @position = position
  end
  
  def position
    @position
  end
  
  def line
    @position.getStartLine + 1
  end
  
  def message
    @message
  end
end

interface ParseResult do
  def ast
    returns Object
  end
  
  def errors
    returns ParseError[]
  end
end

interface DubyCompiler do
  def parse(text:String)
    returns ParseResult
  end
end