require 'test/unit'
require 'mirah'

class TestTyper < Test::Unit::TestCase
  include Duby

  def test_fixnum
    ast = AST.parse("1")

    assert_equal(AST::TypeReference.new("fixnum"), ast.infer(Typer::Simple.new(:bar)))
  end

  def test_float
    ast = AST.parse("1.0")

    assert_equal(AST::TypeReference.new("float"), ast.infer(Typer::Simple.new(:bar)))
  end

  def test_string
    ast = AST.parse("'foo'")

    assert_equal(AST::TypeReference.new("string"), ast.infer(Typer::Simple.new(:bar)))
  end

  def test_boolean
    ast1 = AST.parse("true")
    ast2 = AST.parse("false")

    assert_equal(AST::TypeReference.new("boolean"), ast1.infer(Typer::Simple.new(:bar)))
    assert_equal(AST::TypeReference.new("boolean"), ast2.infer(Typer::Simple.new(:bar)))
  end

  def test_body
    ast1 = AST.parse("'foo'; 1.0; 1")
    ast2 = AST.parse("begin; end")

    assert_equal(AST::TypeReference.new("fixnum"), ast1.infer(Typer::Simple.new(:bar)))
    assert_equal(AST::no_type, ast2.infer(Typer::Simple.new(:bar)))
  end

  def test_local
    ast1 = AST.parse("a = 1; a")
    typer = Typer::Simple.new :bar

    ast1.infer(typer)

    assert_equal(AST::TypeReference.new("fixnum"), typer.local_type(ast1.static_scope, 'a'))
    assert_equal(AST::TypeReference.new("fixnum"), ast1.body.children[0].inferred_type)
    assert_equal(AST::TypeReference.new("fixnum"), ast1.body.children[1].inferred_type)

    ast2 = AST.parse("b = a = 1")
    ast2.infer(typer)

    assert_equal(AST::TypeReference.new("fixnum"), typer.local_type(ast2.static_scope, 'a'))
    assert_equal(AST::TypeReference.new("fixnum"), ast2.body.children[0].inferred_type)
  end

  def test_signature
    ["def foo", "def self.foo"].each do |def_foo|
      ast1 = AST.parse("#{def_foo}(a:string); end")
      typer = Typer::Simple.new :bar

      ast1.infer(typer)

      assert_nothing_raised {typer.resolve(true)}
      assert_nothing_raised {typer.resolve}


      if def_foo =~ /self/
        type = typer.self_type.meta
      else
        type = typer.self_type
      end

      assert_equal(typer.no_type, typer.method_type(type, 'foo', [typer.string_type]))
      assert_equal(typer.string_type, typer.local_type(ast1.body[0].static_scope, 'a'))
      assert_equal(typer.no_type, ast1.body.inferred_type)
      assert_equal(typer.string_type, ast1.body[0].arguments.args[0].inferred_type)

      ast1 = AST.parse("#{def_foo}(a:string); a; end")
      typer = Typer::Simple.new :bar

      ast1.infer(typer)

      assert_equal(typer.string_type, typer.method_type(type, 'foo', [typer.string_type]))
      assert_equal(typer.string_type, typer.local_type(ast1.body[0].static_scope, 'a'))
      assert_equal(typer.string_type, ast1.body[0].inferred_type)
      assert_equal(typer.string_type, ast1.body[0].arguments.args[0].inferred_type)

      ast1 = AST.parse("#{def_foo}(a) returns :string; end")
      typer = Typer::Simple.new :bar

      assert_raise(Typer::InferenceError) do
        ast1.infer(typer)
        typer.resolve(true)
      end
    end
  end

  def test_call
    ast = AST.parse("1.foo(2)").body
    typer = Typer::Simple.new "bar"

    typer.learn_method_type(typer.fixnum_type, "foo", [typer.fixnum_type], typer.string_type, [])
    assert_equal(typer.string_type, typer.method_type(typer.fixnum_type, "foo", [typer.fixnum_type]))

    ast.infer(typer)

    assert_equal(typer.string_type, ast.inferred_type)

    ast = AST.parse("def bar(a:fixnum, b:string); 1.0; end; def baz; bar(1, 'x'); end")

    ast.infer(typer)
    ast = ast.body

    assert_equal(typer.float_type, typer.method_type(typer.self_type, "bar", [typer.fixnum_type, typer.string_type]))
    assert_equal(typer.float_type, typer.method_type(typer.self_type, "baz", []))
    assert_equal(typer.float_type, ast.children[0].inferred_type)
    assert_equal(typer.float_type, ast.children[1].inferred_type)

    # Reverse the order, ensure deferred inference succeeds
    ast = AST.parse("def baz; bar(1, 'x'); end; def bar(a:fixnum, b:string); 1.0; end")
    typer = Typer::Simple.new("bar")

    ast.infer(typer)
    ast = ast.body

    assert_equal(typer.default_type, typer.method_type(typer.self_type, "baz", []))
    assert_equal(typer.float_type, typer.method_type(typer.self_type, "bar", [typer.fixnum_type, typer.string_type]))
    assert_equal(typer.default_type, ast.children[0].inferred_type)
    assert_equal(typer.float_type, ast.children[1].inferred_type)

    # allow resolution to run
    assert_nothing_raised {typer.resolve}

    assert_equal(typer.float_type, typer.method_type(typer.self_type, "baz", []))
    assert_equal(typer.float_type, typer.method_type(typer.self_type, "bar", [typer.fixnum_type, typer.string_type]))
    assert_equal(typer.float_type, ast.children[0].inferred_type)
    assert_equal(typer.float_type, ast.children[1].inferred_type)

    # modify bar call to have bogus types, ensure resolution fails
    ast = AST.parse("def baz; bar(1, 1); end; def bar(a:fixnum, b:string); 1.0; end")
    typer = Typer::Simple.new("bar")

    ast.infer(typer)
    ast = ast.body

    assert_equal(typer.default_type, typer.method_type(typer.self_type, "baz", []))
    assert_equal(typer.float_type, typer.method_type(typer.self_type, "bar", [typer.fixnum_type, typer.string_type]))
    assert_equal(typer.default_type, ast.children[0].inferred_type)
    assert_equal(typer.float_type, ast.children[1].inferred_type)

    # allow resolution to run and produce error
    assert_raise(Typer::InferenceError) {typer.resolve(true)}
    error_nodes = typer.errors.map {|e| e.node}
    inspected = "[FunctionalCall(bar)\n Fixnum(1)\n Fixnum(1)]"
    assert_equal(inspected, error_nodes.inspect)
  end

  def test_if
    ast = AST.parse("if true; 1.0; else; ''; end").body[0]
    typer = Typer::Simple.new("bar")

    # incompatible body types
    assert_raise(Typer::InferenceError) {ast.infer(typer)}

    ast = AST.parse("if true; 1.0; else; 2.0; end").body[0]

    assert_nothing_raised {ast.infer(typer); typer.resolve(true)}

    assert_equal(typer.boolean_type, ast.condition.inferred_type)
    assert_equal(typer.float_type, ast.body.inferred_type)
    assert_equal(typer.float_type, ast.else.inferred_type)

    ast = AST.parse("if foo; bar; else; baz; end").body[0]

    assert_nothing_raised {ast.infer(typer)}

    assert_equal(typer.default_type, ast.condition.inferred_type)
    assert_equal(typer.default_type, ast.body.inferred_type)
    assert_equal(typer.default_type, ast.else.inferred_type)

    # unresolved types for the foo, bar, and baz calls
    assert_raise(Typer::InferenceError) {typer.resolve(true)}

    ast2 = AST.parse("def foo; 1; end; def bar; 1.0; end")[0]

    ast2.infer(typer)
    ast.infer(typer)

    # unresolved types for the baz call
    assert_raise(Typer::InferenceError) {typer.resolve(true)}

    assert_equal(AST.error_type, ast.condition.inferred_type)
    assert_equal(AST.error_type, ast.body.inferred_type)
    assert_equal(AST.error_type, ast.else.inferred_type)

    typer.errors.clear

    ast2 = AST.parse("def baz; 2.0; end")

    ast2.infer(typer)
    ast.infer(typer)

    assert_nothing_raised {typer.resolve(true)}

    assert_equal(typer.float_type, ast2.body[0].inferred_type)
  end

  def test_class
    ast = AST.parse("class Foo; def foo; 1; end; def baz; foo; end; end")
    cls = ast.body[0]
    foo = cls.body[0]
    baz = cls.body[1]

    typer = Typer::Simple.new("script")
    ast.infer(typer)

    assert_nothing_raised {typer.resolve(true)}

    assert_not_nil(typer.known_types["Foo"])
    assert(AST::TypeDefinition === typer.known_types["Foo"])
    assert_equal(typer.known_types["Foo"], cls.inferred_type)
  end
end