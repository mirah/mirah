class Foo
  def initialize
    puts 'constructor'
    @hello = 'Hello, '
  end

  def hello(a:string)
    puts @hello; puts a
  end
end

Foo.new.hello('Mirah')
