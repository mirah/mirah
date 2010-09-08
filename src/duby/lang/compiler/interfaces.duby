import java.util.List
import java.lang.Class as JavaClass

interface Node do
  def child_nodes
    returns List
  end
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

  # defmacro quote(&block) do
  #   encoded = @duby.dump_ast(block.body)
  #   quote { @duby.load_ast(`encoded`) }
  # end
  macro def quote(&block)
    encoded = @mirah.dump_ast(block.body)
    code = <<RUBY
  call = eval("@mirah.load_ast(x)")
  call.parameters[0] = arg
  arg.parent = call
RUBY
    @mirah.__ruby_eval(code, encoded)
  end
end

interface Class do
  def load_extensions(from:JavaClass)
    returns void
  end
end

interface Compiler do
  # defmacro quote(&block) do
  #   encoded = @duby.dump_ast(block.body)
  #   quote { @duby.load_ast(`encoded`) }
  # end

  def find_class(name:String)
    returns Class
  end

  def dump_ast(node:Node)
    returns Object
  end

  def load_ast(serialized:Object)
    returns Node
  end

  def __ruby_eval(code:String, arg:Object)
    returns Node
  end

  def fixnum(x:int)
    returns Node
  end

  def constant(name:String)
    returns Node
  end
end

# abstract class Macro
#   abstract def expand
#     returns Node
#   end
# end