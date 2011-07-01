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
  include Mirah::Util::ProcessErrors

  def setup
    @scopes = Mirah::Types::Scoper.new
    @types = Mirah::Types::SimpleTypes.new
  end

  def parse(text)
    AST.parse(text, '-', false, @mirah)
  end

  def new_typer(n)
    @typer = Mirah::Typer::Typer.new(@types, @scopes)
  end

  def inferred_type(node)
    type = @typer.infer(node, false).resolve
    if type.name == ':error'
      catch(:exit) do
        process_errors([type])
      end
    end
    type
  end

  def infer(ast, expression=true)
    new_typer(:bar).infer(ast, expression)
    inferred_type(ast)
  end

  def test_fixnum
    ast = parse("1")
    assert_equal(@types.getFixnumType(1), infer(ast))
  end

  def test_float
    ast = parse("1.0")
    new_typer(:bar).infer(ast, true)
    assert_equal(@types.getFloatType(1.0), infer(ast))
  end

  def test_string
    ast = parse("'foo'")

    assert_equal(@types.getStringType, infer(ast))
  end

  def test_boolean
    ast1 = parse("true")
    ast2 = parse("false")

    assert_equal(@types.getBooleanType, infer(ast1))
    assert_equal(@types.getBooleanType, infer(ast2))
  end

  def test_body
    ast1 = parse("'foo'; 1.0; 1")
    ast2 = parse("begin; end")

    assert_equal(@types.getFixnumType(1), infer(ast1))
    assert_equal(@types.getNullType, infer(ast2))
  end

  def test_local
    ast1 = parse("a = 1; a")
    infer(ast1)

    assert_equal(@types.getFixnumType(1), @types.getLocalType(@scopes.getScope(ast1.get(0)), 'a'))
    assert_equal(@types.getFixnumType(1), inferred_type(ast1.body.get(0)))
    assert_equal(@types.getFixnumType(1), inferred_type(ast1.body.get(1)))

    ast2 = parse("b = a = 1")
    infer(ast2)

    assert_equal(@types.getFixnumType(1), @types.getLocalType(@scopes.getScope(ast2.get(0)), 'a'))
    assert_equal(@types.getFixnumType(1), inferred_type(ast2.body.get(0)))
  end

  def test_signature
    ["def foo", "def self.foo"].each do |def_foo|
      ast1 = parse("#{def_foo}(a:string); end")
      infer(ast1)

      assert_nothing_raised {typer.resolve(true)}
      assert_nothing_raised {typer.resolve}


      if def_foo =~ /self/
        type = typer.self_type.meta
      else
        type = typer.self_type
      end

      mdef = ast1.body
      mdef = mdef[0] if AST::Body === mdef

      assert_equal(@types.getNullType, typer.method_type(type, 'foo', [typer.getStringType]))
      assert_equal(@types.geStringType, typer.local_type(@mirah.introduced_scope(mdef), 'a'))
      assert_equal(@types.getNullType, mdef.inferred_type)
      assert_equal(@types.getStringType, mdef.arguments.args[0].inferred_type)

      ast1 = parse("#{def_foo}(a:string); a; end")
      typer = new_typer :bar

      ast1.infer(typer, true)
      assert_equal(@types.getStringType, typer.method_type(type, 'foo', [typer.getStringType]))
      assert_equal(@types.getStringType, typer.local_type(@mirah.introduced_scope(ast1.body), 'a'))
      assert_equal(@types.getStringType, ast1.body.inferred_type)
      assert_equal(@types.getStringType, ast1.body.arguments.args[0].inferred_type)

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

    @types.getMethodDefType(@types.getFixnumType(1), 'foo', [@types.getFixnumType(1)]).assign(@types.getStringType, nil)

    assert_equal(@types.getStringType, infer(ast))

    ast = parse("def bar(a:fixnum, b:string); 1.0; end; def baz; bar(1, 'x'); end")

    infer(ast)
    ast = ast.body
    self_type = @scopes.getScope(ast.get(0)).selfType
    assert_equal(@types.getFloatType(1.0), @types.getMethodType(self_type, 'bar', [typer.getFixnumType(1), typer.getStringType]).resolve)
    assert_equal(@types.getFloatType, @types.getMethodType(self_type, 'baz', []))
    assert_equal(@types.getFloatType, inferred_type(ast.get(0)))
    assert_equal(@types.getFloatType, inferred_type(ast.get(1)))

    # Reverse the order, ensure deferred inference succeeds
    ast = parse("def baz; bar(1, 'x'); end; def bar(a:fixnum, b:string); 1.0; end")
    typer = new_typer("bar")

    ast.infer(typer, true)
    ast = ast.body

    assert_equal(@types.default_type, typer.method_type(typer.self_type, "baz", []))
    assert_equal(@types.getFloatType, typer.method_type(typer.self_type, "bar", [typer.getFixnumType, typer.getStringType]))
    assert_equal(@types.default_type, ast.children[0].inferred_type)
    assert_equal(@types.getFloatType, ast.children[1].inferred_type)

    # allow resolution to run
    assert_nothing_raised {typer.resolve}

    assert_equal(@types.getFloatType, typer.method_type(typer.self_type, "baz", []))
    assert_equal(@types.getFloatType, typer.method_type(typer.self_type, "bar", [typer.getFixnumType, typer.getStringType]))
    assert_equal(@types.getFloatType, ast.children[0].inferred_type)
    assert_equal(@types.getFloatType, ast.children[1].inferred_type)

    # modify bar call to have bogus types, ensure resolution fails
    ast = parse("def baz; bar(1, 1); end; def bar(a:fixnum, b:string); 1.0; end")
    typer = new_typer("bar")

    ast.infer(typer, true)
    ast = ast.body

    assert_equal(@types.default_type, typer.method_type(typer.self_type, "baz", []))
    assert_equal(@types.getFloatType, typer.method_type(typer.self_type, "bar", [typer.getFixnumType, typer.getStringType]))
    assert_equal(@types.default_type, ast.children[0].inferred_type)
    assert_equal(@types.getFloatType, ast.children[1].inferred_type)

    # allow resolution to run and produce error
    assert_raise(Typer::InferenceError) {typer.resolve(true)}
    error_nodes = typer.errors.map {|e| e.node}
    inspected = "[FunctionalCall(bar)\n Fixnum(1)\n Fixnum(1)]"
    assert_equal(inspected, error_nodes.inspect)
  end

  def test_if
    ast = parse("if true; 1.0; else; ''; end").body

    # incompatible body types
    assert_equal(':error', infer(ast).name)

    ast = parse("if true; 1.0; else; 2.0; end").body

    assert_not_equal(':error', infer(ast).name)

    assert_equal(@types.getBooleanType, inferred_type(ast.condition))
    assert_equal(@types.getFloatType(1.0), inferred_type(ast.body))
    assert_equal(@types.getFloatType(1.0), inferred_type(ast.elseBody))

    typer = new_typer(:bar)

    ast = parse("if foo; bar; else; baz; end").body
    typer.infer(ast, true)
    assert_equal(':error', inferred_type(ast).name)

    ast2 = parse("def foo; 1; end; def bar; 1.0; end")

    typer.infer(ast2, true)

    # unresolved types for the baz call
    assert_equal(':error', inferred_type(ast).name)

    assert_equal(AST.getFixnumType(1), inferred_type(ast.condition))
    assert_equal(AST.getFloatType(1.0), inferred_type(ast.body))
    assert_equal(':error', inferred_type(ast.elseBody).name)

    ast2 = parse("def baz; 2.0; end")
    typer.infer(ast2, true)

    assert_not_equal(':error', infer(ast).name)

    assert_equal(@types.getFloatType(1.0), ast2.body.inferred_type)
  end

  def test_class
    ast = parse("class Foo; def foo; 1; end; def baz; foo; end; end")
    cls = ast.body[0]
    foo = cls.body[0]
    baz = cls.body[1]

    typer = new_typer("script")
    typer.infer(ast, true)

    assert_nothing_raised {typer.resolve(true)}
  end
end