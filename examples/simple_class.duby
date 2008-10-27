class Foo
  def initialize
    puts 'constructor'
  end

  def hello(a => :string)
    puts 'Hello, '; puts a
  end
end

Foo.new.hello('Duby')
