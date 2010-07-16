# Example of using a dynamic type in a method definition
def foo(a:dynamic)
  puts "I got a #{a.getClass.getName} of size #{a.size}"
end

class SizeThing
  def initialize(size:int)
    @size = size
  end

  def size
    @size
  end
end

foo([1,2,3])
foo(SizeThing.new(12))
