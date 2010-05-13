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

interface Compiler do
  
end

# abstract class Macro
#   abstract def expand
#     returns Node
#   end
# end

interface Macro do
  def expand
    returns Node
  end
end