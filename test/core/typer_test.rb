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
require 'test_helper'

class TyperTest < Test::Unit::TestCase
  include Mirah
  include Mirah::Util::ProcessErrors
  java_import 'org.mirah.typer.TypeFuture'
  java_import 'org.mirah.typer.simple.SimpleScoper'
  java_import 'org.mirah.typer.simple.SimpleTypes'
  java_import 'mirah.lang.ast.VCall'
  java_import 'mirah.lang.ast.FunctionalCall'
  java_import 'mirah.lang.ast.LocalAccess'

  module TypeFuture
    def inspect
      toString
    end
  end

  def setup
    @scopes = SimpleScoper.new
    @types = SimpleTypes.new('bar')
    new_typer('bar')
  end

  def parse(text)
    AST.parse(text, '-', false, @mirah)
  end

  def new_typer(n)
    @types = SimpleTypes.new(n.to_s)
    @typer = Mirah::Typer::Typer.new(@types, @scopes, nil)
    @mirah = Transform::Transformer.new(Mirah::Util::CompilationState.new, @typer)
    @typer
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

  def assert_no_errors(typer, ast)
    process_inference_errors(typer, [ast]) do |errors|
      errors.each {|e| add_failure(e.message)}
    end
  end

  def assert_errors_including(message, typer, ast)
    actual_errors = []
    process_inference_errors(typer, [ast]) do |errors|
      actual_errors += errors
    end
    fail("no errors") if actual_errors.empty?
    assert actual_errors.any?{|error| error.message.join("\n").include? message },
           "no errors with message \"#{message}\" in [#{actual_errors}"
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

    assert_equal(@types.getFixnumType(1), @types.getLocalType(@scopes.getScope(ast1), 'a', nil).resolve)
    assert_equal(@types.getFixnumType(1), inferred_type(ast1.body.get(0)))
    assert_equal(@types.getFixnumType(1), inferred_type(ast1.body.get(1)))

    ast2 = parse("b = a = 1")
    infer(ast2)

    assert_equal(@types.getFixnumType(1), @types.getLocalType(@scopes.getScope(ast2), 'a', nil).resolve)
    assert_equal(@types.getFixnumType(1), inferred_type(ast2.body.get(0)))
  end

  def test_signature
    signature_test(false)
  end

  def test_static_signature
    signature_test(true)
  end

  def signature_test(is_static)
    if is_static
      def_foo = "def self.foo"
    else
      def_foo = "def foo"
    end
    ast1 = parse("#{def_foo}(a:String); end")
    typer = new_typer(:bar)
    typer.infer(ast1, true)

    assert_no_errors(typer, ast1)


    type = @types.getMainType(@scopes.getScope(ast1), ast1)
    type = @types.getMetaType(type) if is_static

    mdef = ast1.body.get(0)
    inner_scope = @scopes.getScope(mdef.body)

#    assert_equal(@types.getNullType, @types.getMethodType(type, 'foo', [@types.getStringType.resolve]).resolve)
    assert_equal(@types.getStringType, @types.getLocalType(inner_scope, 'a', nil).resolve)
    assert_equal(@types.getNullType, inferred_type(mdef).returnType)
    assert_equal(@types.getStringType, inferred_type(mdef.arguments.required.get(0)))

    ast1 = parse("#{def_foo}(a:String); a; end")
    typer = new_typer :bar
    typer.infer(ast1, true)
    mdef = ast1.body.get(0)
    inner_scope = @scopes.getScope(mdef.body)

    # assert_equal(@types.getStringType, @types.getMethodType(type, 'foo', [@types.getStringType.resolve]).resolve)
    assert_equal(@types.getStringType, @types.getLocalType(inner_scope, 'a', nil).resolve)
    assert_equal(@types.getStringType, inferred_type(mdef).returnType)
    assert_equal(@types.getStringType, inferred_type(mdef.arguments.required.get(0)))
  end

  def test_call
    ast = parse("class Int;def foo(a:Int):String; end; end; 1.foo(2)")

    assert_equal(@types.getStringType, infer(ast))

    ast = parse("def bar(a:Int, b:String); 1.0; end; def baz; bar(1, 'x'); end")

    infer(ast)
    ast = ast.body
    self_type = @scopes.getScope(ast.get(0)).selfType
    assert_equal(@types.getFloatType(1.0), inferred_type(ast.get(0)).returnType)
    assert_equal(@types.getFloatType(1.0), inferred_type(ast.get(1)).returnType)

    # Reverse the order, ensure deferred inference succeeds
    ast = parse("def baz; bar(1, 'x'); end; def bar(a:Int, b:String); 1.0; end")
    typer = new_typer("bar")

    typer.infer(ast, true)
    ast = ast.body

    assert_no_errors(typer, ast)

    assert_equal(@types.getFloatType(1.0), inferred_type(ast.get(0)).returnType)
    assert_equal(@types.getFloatType(1.0), inferred_type(ast.get(1)).returnType)

    # modify bar call to have bogus types, ensure resolution fails
    ast = parse("def baz; bar(1, 1); end; def bar(a:Int, b:String); 1.0; end")
    typer = new_typer("bar")

    typer.infer(ast, true)
    ast = ast.body

    assert_equal(":error", inferred_type(ast.get(0)).name)
    assert_equal(@types.getFloatType(1.0), inferred_type(ast.get(1)).returnType)
  end

  def test_if
    ast = parse("if true; 1.0; else; ''; end").body

    # incompatible body types
    assert_equal(':error', infer(ast).name)

    ast = parse("if true; 1.0; else; 2.0; end").body.get(0)

    assert_not_equal(':error', infer(ast).name)

    assert_equal(@types.getBooleanType, inferred_type(ast.condition))
    assert_equal(@types.getFloatType(1.0), inferred_type(ast.body))
    assert_equal(@types.getFloatType(1.0), inferred_type(ast.elseBody))

    typer = new_typer(:bar)

    ast = parse("if foo; bar; else; baz; end").body.get(0)
    typer.infer(ast.parent.parent, true)
    assert_equal(':error', inferred_type(ast).name)

    ast2 = parse("def foo; 1; end; def bar; 1.0; end")

    typer.infer(ast2, true)

    # unresolved types for the baz call
    assert_equal(':error', inferred_type(ast.elseBody).name)

    assert_equal(@types.getFixnumType(1), inferred_type(ast.condition))
    assert_equal(@types.getFloatType(1.0), inferred_type(ast.body))

    ast2 = parse("def baz; 2.0; end")
    typer.infer(ast2, true)

    assert_equal(@types.getFloatType(1.0), inferred_type(ast2.body))

    assert_equal(@types.getFloatType(1.0), inferred_type(ast))
    assert_equal(@types.getFloatType(1.0), inferred_type(ast.elseBody))
  end

  def test_class
    ast = parse("class Foo; def foo; 1; end; def baz; foo; end; end")
    cls = ast.body.get(0)
    foo = cls.body.get(0)
    baz = cls.body.get(1)

    typer = new_typer("script")
    typer.infer(ast, true)

    assert_no_errors(typer, ast)
  end

  def test_rescue_w_different_type_raises_inference_error_when_expression
    ast = parse("1 + begin true; 1.0; rescue; ''; end")
    infer(ast, true)
    assert_errors_including "Incompatible types", @typer, ast
  end

  def test_rescue_w_different_type_doesnt_raise_inference_error_when_statement
    ast = parse("begin true; 1.0; rescue; ''; end")
    infer(ast, false)
    assert_no_errors @typer, ast
  end

  def test_colon2
    ast = parse("java::lang::System.out")
    infer(ast)
    target_type = inferred_type(ast.body(0).target)
    assert_equal('java.lang.System', target_type.name)
  end

  def test_static_method
    ast = parse("class Foo; def self.bar;1; end; end; Foo.bar")
    assert_equal(@types.getFixnumType(1), infer(ast))
  end

  def test_vcall
    ast = parse("foo = 1; def bar; end; foo; bar")
    assert_kind_of(VCall, ast.body(2))
    assert_kind_of(VCall, ast.body(3))
    infer(ast)
    assert_equal(@types.getFixnumType(1), inferred_type(ast.body(2)))
    assert_equal(@types.getNullType, inferred_type(ast.body(3)))
    assert_kind_of(LocalAccess, ast.body(2))
    assert_kind_of(FunctionalCall, ast.body(3))
  end
end
