import 'java.util.ArrayList'

class Bar
  def initialize
    @a = ArrayList(nil)
  end

  def list(a:ArrayList)
    @a = a
  end

  def foo
    puts @a
  end
end

b = Bar.new
list = ArrayList.new
list.add('hello')
list.add('world')
b.list(list)
b.foo
