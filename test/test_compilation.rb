require 'duby'
require 'duby/compiler'
require 'test/unit'
require 'jruby'

class TestAst < Test::Unit::TestCase
  include Duby

  class MockCompiler
    attr_accessor :calls

    def initialize
      @calls = []
    end
    def compile(ast)
      ast.compile(self, true)
    end

    def line(num)
      # ignore newlines
    end

    def method_missing(sym, *args, &block)
      calls << [sym, *args]
      block.call if block
    end
  end

  class ClassComparison
    def initialize(klass)
      @class = klass
    end

    def ==(other)
      other.kind_of?(@class)
    end
  end

  def a(klass)
    ClassComparison.new(klass)
  end

  def setup
    @compiler = MockCompiler.new
  end

  def test_fixnum
    new_ast = AST.parse("1").body[0]

    new_ast.compile(@compiler, true)

    assert_equal([[:fixnum, 1]], @compiler.calls)
  end

  def test_string
    new_ast = AST.parse("'foo'").body[0]

    new_ast.compile(@compiler, true)

    assert_equal([[:string, "foo"]], @compiler.calls)
  end

  def test_float
    new_ast = AST.parse("1.0").body[0]

    new_ast.compile(@compiler, true)

    assert_equal([[:float, 1.0]], @compiler.calls)
  end

  def test_boolean
    new_ast = AST.parse("true").body[0]

    new_ast.compile(@compiler, true)

    assert_equal([[:boolean, true]], @compiler.calls)
  end

  def test_local
    new_ast = AST.parse("a = 1").body[0]

    new_ast.compile(@compiler, true)

    assert_equal([[:local_assign, a(Duby::AST::Script), "a", nil, true, AST.fixnum(nil, nil, 1)]], @compiler.calls)
  end

  def test_local_typed
    new_ast = AST.parse("a = 1").body[0]
    typer = Typer::Simple.new(:bar)
    new_ast.infer(typer)
    new_ast.compile(@compiler, true)

    assert_equal([[:local_assign, a(Duby::AST::Script), "a", AST.type(:fixnum), true, AST.fixnum(nil, nil, 1)]], @compiler.calls)
  end

  def test_return
    new_ast = AST.parse("return 1").body[0]
    new_ast.compile(@compiler, true)

    assert_equal([[:return, new_ast]], @compiler.calls)
  end

  def test_empty_array
    new_ast = AST.parse("int[5]").body[0]
    new_ast.compile(@compiler, true)

    assert_equal(1, @compiler.calls.size)
    size = @compiler.calls[0].pop
    assert_equal([[:empty_array, AST.type(:int)]], @compiler.calls)
    assert_equal(5, size.literal)
  end
end