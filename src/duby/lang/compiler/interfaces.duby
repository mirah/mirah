import java.util.List

interface Node do
  
end

interface Block < Node do
  def body
    returns Node
  end
end

interface Call < Node do
  def arguments
    returns List
  end

  def block
    returns Block
  end

  def target
    returns Node
  end
end

interface Macro do
  def expand
    returns Node
  end

  defmacro quote(&block) do
    encoded = @duby.dump_ast(block.body)
    code = <<RUBY
      ast, args = arg
      eval("@duby.load_ast(['\#{ast}', \#{args.join(', ')}])")
RUBY

    @duby.__ruby_eval(code, encoded)
  end
end

interface Class do
  def add_macro(macro:Macro)
    returns void
  end
end

interface Compiler do
  def dump_ast(node:Node)
    returns Object
  end

  def load_ast(serialized:Object)
    returns Node
  end

  def __ruby_eval(code:String, arg:Object)
    returns Node
  end
end

# abstract class Macro
#   abstract def expand
#     returns Node
#   end
# end