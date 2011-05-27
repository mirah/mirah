# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
# All contributing project authors may be found in the NOTICE file.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'test/unit'

$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'mirah'

class TestTyper < Test::Unit::TestCase
  include Mirah

  def setup
    @mirah = Mirah::Transform::Transformer.new(Mirah::Util::CompilationState.new)
  end

  def parse(text)
    AST.parse(text, '-', false, @mirah)
  end

  def new_typer(n)
    typer = Typer::Simple.new(n)
    typer.scopes = @mirah.scopes
    typer
  end

  def test_fixnum
    ast = parse("1")

    assert_equal(AST::TypeReference.new("fixnum"), ast.infer(new_typer(:bar), true))
  end

  def test_float
    ast = parse("1.0")

    assert_equal(AST::TypeReference.new("float"), ast.infer(new_typer(:bar), true))
  end

  def test_string
    ast = parse("'foo'")

    assert_equal(AST::TypeReference.new("string"), ast.infer(new_typer(:bar), true))
  end

  def test_boolean
    ast1 = parse("true")
    ast2 = parse("false")

    assert_equal(AST::TypeReference.new("boolean"), ast1.infer(new_typer(:bar), true))
    assert_equal(AST::TypeReference.new("boolean"), ast2.infer(new_typer(:bar), true))
  end

  def test_body
    ast1 = parse("'foo'; 1.0; 1")
    ast2 = parse("begin; end")

    assert_equal(AST::TypeReference.new("fixnum"), ast1.infer(new_typer(:bar), true))
    assert_equal(AST::TypeReference::NullType, ast2.infer(new_typer(:bar), true))
  end

  def test_local
    ast1 = parse("a = 1; a")
    typer = new_typer :bar

    ast1.infer(typer, true)

    assert_equal(AST::TypeReference.new("fixnum"), typer.local_type(@mirah.get_scope(ast1), 'a'))
    assert_equal(AST::TypeReference.new("fixnum"), ast1.body.children[0].inferred_type)
    assert_equal(AST::TypeReference.new("fixnum"), ast1.body.children[1].inferred_type)

    ast2 = parse("b = a = 1")
    ast2.infer(typer, true)

    assert_equal(AST::TypeReference.new("fixnum"), typer.local_type(@mirah.get_scope(ast2), 'a'))
    assert_equal(AST::TypeReference.new("fixnum"), ast2.body.children[0].inferred_type)
  end

  def test_signature
    ["def foo", "def self.foo"].each do |def_foo|
      ast1 = parse("#{def_foo}(a:string); end")
      typer = new_typer :bar

      ast1.infer(typer, true)

      assert_nothing_raised {typer.resolve(true)}
      assert_nothing_raised {typer.resolve}


      if def_foo =~ /self/
        type = typer.self_type.meta
      else
        type = typer.self_type
      end

      mdef = ast1.body
      mdef = mdef[0] if AST::Body === mdef

      assert_equal(typer.null_type, typer.method_type(type, 'foo', [typer.string_type]))
      assert_equal(typer.string_type, typer.local_type(@mirah.introduced_scope(mdef), 'a'))
      assert_equal(typer.null_type, mdef.inferred_type)
      assert_equal(typer.string_type, mdef.arguments.args[0].inferred_type)

      ast1 = parse("#{def_foo}(a:string); a; end")
      typer = new_typer :bar

      ast1.infer(typer, true)
      assert_equal(typer.string_type, typer.method_type(type, 'foo', [typer.string_type]))
      assert_equal(typer.string_type, typer.local_type(@mirah.introduced_scope(ast1.body), 'a'))
      assert_equal(typer.string_type, ast1.body.inferred_type)
      assert_equal(typer.string_type, ast1.body.arguments.args[0].inferred_type)

      ast1 = parse("#{def_foo}(a) returns :string; end")
      typer = new_typer :bar

      assert_raise(Typer::InferenceError) do
        ast1.infer(typer, true)
        typer.resolve(true)
      end
    end
  end

  def test_call
    ast = parse("1.foo(2)").body
    typer = new_typer "bar"

    typer.learn_method_type(typer.fixnum_type, "foo", [typer.fixnum_type], typer.string_type, [])
    assert_equal(typer.string_type, typer.method_type(typer.fixnum_type, "foo", [typer.fixnum_type]))

    ast.infer(typer, true)

    assert_equal(typer.string_type, ast.inferred_type)

    ast = parse("def bar(a:fixnum, b:string); 1.0; end; def baz; bar(1, 'x'); end")

    ast.infer(typer, true)
    ast = ast.body

    assert_equal(typer.float_type, typer.method_type(typer.self_type, "bar", [typer.fixnum_type, typer.string_type]))
    assert_equal(typer.float_type, typer.method_type(typer.self_type, "baz", []))
    assert_equal(typer.float_type, ast.children[0].inferred_type)
    assert_equal(typer.float_type, ast.children[1].inferred_type)

    # Reverse the order, ensure deferred inference succeeds
    ast = parse("def baz; bar(1, 'x'); end; def bar(a:fixnum, b:string); 1.0; end")
    typer = new_typer("bar")

    ast.infer(typer, true)
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
    ast = parse("def baz; bar(1, 1); end; def bar(a:fixnum, b:string); 1.0; end")
    typer = new_typer("bar")

    ast.infer(typer, true)
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
    ast = parse("if true; 1.0; else; ''; end").body[0]
    typer = new_typer("bar")

    # incompatible body types
    assert_raise(Typer::InferenceError) {ast.infer(typer, true)}
    assert_nothing_raised {ast.infer(typer, false)}

    ast = parse("if true; 1.0; else; 2.0; end").body

    assert_nothing_raised {ast.infer(typer, true); typer.resolve(true)}

    assert_equal(typer.boolean_type, ast.condition.inferred_type)
    assert_equal(typer.float_type, ast.body.inferred_type)
    assert_equal(typer.float_type, ast.else.inferred_type)

    ast = parse("if foo; bar; else; baz; end").body

    assert_nothing_raised {ast.infer(typer, true)}

    assert_equal(typer.default_type, ast.condition.inferred_type)
    assert_equal(typer.default_type, ast.body.inferred_type)
    assert_equal(typer.default_type, ast.else.inferred_type)

    # unresolved types for the foo, bar, and baz calls
    assert_raise(Typer::InferenceError) {typer.resolve(true)}

    ast2 = parse("def foo; 1; end; def bar; 1.0; end")

    ast2.infer(typer, true)
    ast.infer(typer, true)

    # unresolved types for the baz call
    assert_raise(Typer::InferenceError) {typer.resolve(true)}

    assert_equal(AST.error_type, ast.condition.inferred_type)
    assert_equal(AST.error_type, ast.body.inferred_type)
    assert_equal(AST.error_type, ast.else.inferred_type)

    typer.errors.clear

    ast2 = parse("def baz; 2.0; end")

    ast2.infer(typer, true)
    ast.infer(typer, true)

    assert_nothing_raised {typer.resolve(true)}

    assert_equal(typer.float_type, ast2.body.inferred_type)
  end

  def test_class
    ast = parse("class Foo; def foo; 1; end; def baz; foo; end; end")
    cls = ast.body[0]
    foo = cls.body[0]
    baz = cls.body[1]

    typer = new_typer("script")
    ast.infer(typer, true)

    assert_nothing_raised {typer.resolve(true)}
  end
end