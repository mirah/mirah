class ParseError
  def initialize(line => :int, message => String)
    @line = line
    @message = message
  end
  
  def line
    @line
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
  def parse(text => String)
    returns ParseResult
  end
end