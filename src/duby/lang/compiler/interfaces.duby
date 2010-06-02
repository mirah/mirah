import java.util.List

interface Node do
  
end

interface Call < Node do
  def arguments
    returns List
  end

  def block
    returns Node
  end

  def target
    returns Node
  end
end

interface Macro do
  def expand
    returns Node
  end
end

interface Class do
  def add_macro(macro:Macro)
    returns void
  end
end

interface Compiler do
  def find_class(name:String)
    returns Class
  end

  def dump_ast(node:Node)
    returns Object
  end

  def load_ast(serialized:Object)
    returns Node
  end
end

# abstract class Macro
#   abstract def expand
#     returns Node
#   end
# end