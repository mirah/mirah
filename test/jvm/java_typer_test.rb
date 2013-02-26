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
require 'mirah'

class JavaTyperTest < Test::Unit::TestCase
  include Mirah
  include Mirah::Util::ProcessErrors

  java_import 'org.mirah.typer.simple.SimpleScoper'
  java_import 'org.mirah.typer.BaseTypeFuture'
  java_import 'org.mirah.typer.CallFuture'
  java_import 'org.mirah.typer.TypeFuture'

  def setup
    @types = Mirah::JVM::Types::TypeFactory.new
    @scopes = SimpleScoper.new {|scoper, node| Mirah::AST::StaticScope.new(node, scoper)}
    @typer = Mirah::Typer::Typer.new(@types, @scopes, nil)
    @mirah = Mirah::Transform::Transformer.new(Mirah::Util::CompilationState.new, @typer)
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

  def method_type(target, name, args)
    target = @types.cache_and_wrap(target)
    args = args.map {|arg| @types.cache_and_wrap(arg) }
    call = CallFuture.new(@types, nil, target, name, args, nil, nil)
    @types.getMethodType(call).return_type
  end

  def parse(text)
    AST.parse(text, '-', false, @mirah)
  end

  def test_simple_overtyped_meta_method
    string_meta = @types.type(nil, 'java.lang.String', false, true)
    string = @types.type(nil, 'java.lang.String')

    # integral types
    ['boolean', 'char', 'double', 'float', 'int', 'long'].each do |type_name|
      type = @types.type(nil, type_name)
      return_type = method_type(string_meta, 'valueOf', [type])
      assert_equal(string, return_type.resolve, "valueOf(#{type}) should return #{string}")
    end

    # char[]
    type = @types.type(nil, 'char', true)
    return_type = method_type(string_meta, 'valueOf', [type])
    assert_equal(string, return_type.resolve)

    # Object
    type = @types.type(nil, 'java.lang.Object')
    return_type = method_type(string_meta, 'valueOf', [type])
    assert_equal(string, return_type.resolve)
  end

  def test_non_overtyped_method
    string = @types.type(nil, 'java.lang.String')

    int = @types.type(nil, 'int')
    return_type = method_type(string, 'length', [])
    assert_equal(int, return_type.resolve)

    byte_array = @types.type(nil, 'byte', true)
    return_type = method_type(string, 'getBytes', [])
    assert_equal(byte_array, return_type.resolve)
  end

  def test_simple_overtyped_method
    string_meta = @types.type(nil, 'java.lang.String', false, true)
    string = @types.type(nil, 'java.lang.String')

    return_type = method_type(string_meta, 'valueOf', [string])
    assert_equal(string, return_type.resolve)
  end

  def test_primitive_conversion_method
    string = @types.type(nil, 'java.lang.String')
    byte = @types.type(nil, 'byte')
    char = @types.type(nil, 'char')
    long = @types.type(nil, 'long')

    return_type = method_type(string, 'charAt', [byte])
    assert_kind_of(TypeFuture, return_type)
    assert_equal(char, return_type.resolve)

    return_type = method_type(string, 'charAt', [long]).resolve
    assert(return_type.isError)
  end

  include Mirah::JVM::MethodLookup

  def test_is_more_specific
    object = @types.type(nil, 'java.lang.Object')
    charseq = @types.type(nil, 'java.lang.CharSequence')
    string = @types.type(nil, 'java.lang.String')

    assert object.is_more_specific?([string], [object])
    assert object.is_more_specific?([charseq], [object])
    assert object.is_more_specific?([string], [charseq])
  end

  def test_primitive_convertible
    boolean = @types.type(nil, 'boolean')
    byte = @types.type(nil, 'byte')
    short = @types.type(nil, 'short')
    char = @types.type(nil, 'char')
    int = @types.type(nil, 'int')
    long = @types.type(nil, 'long')
    float = @types.type(nil, 'float')
    double = @types.type(nil, 'double')

    assert !primitive_convertible?(boolean, byte)
    assert !primitive_convertible?(boolean, short)
    assert !primitive_convertible?(boolean, char)
    assert !primitive_convertible?(boolean, int)
    assert !primitive_convertible?(boolean, long)
    assert !primitive_convertible?(boolean, float)
    assert !primitive_convertible?(boolean, double)
    assert primitive_convertible?(boolean, boolean)

    assert !primitive_convertible?(byte, boolean)
    assert primitive_convertible?(byte, byte)
    assert primitive_convertible?(byte, short)
    assert !primitive_convertible?(byte, char)
    assert primitive_convertible?(byte, int)
    assert primitive_convertible?(byte, long)
    assert primitive_convertible?(byte, float)
    assert primitive_convertible?(byte, double)

    assert !primitive_convertible?(short, boolean)
    assert !primitive_convertible?(short, byte)
    assert !primitive_convertible?(short, char)
    assert primitive_convertible?(short, short)
    assert primitive_convertible?(short, int)
    assert primitive_convertible?(short, long)
    assert primitive_convertible?(short, float)
    assert primitive_convertible?(short, double)

    assert !primitive_convertible?(char, boolean)
    assert !primitive_convertible?(char, byte)
    assert !primitive_convertible?(char, short)
    assert primitive_convertible?(char, char)
    assert primitive_convertible?(char, int)
    assert primitive_convertible?(char, long)
    assert primitive_convertible?(char, float)
    assert primitive_convertible?(char, double)

    assert !primitive_convertible?(int, boolean)
    assert !primitive_convertible?(int, byte)
    assert !primitive_convertible?(int, short)
    assert !primitive_convertible?(int, char)
    assert primitive_convertible?(int, int)
    assert primitive_convertible?(int, long)
    assert primitive_convertible?(int, float)
    assert primitive_convertible?(int, double)

    assert !primitive_convertible?(long, boolean)
    assert !primitive_convertible?(long, byte)
    assert !primitive_convertible?(long, short)
    assert !primitive_convertible?(long, char)
    assert !primitive_convertible?(long, int)
    assert primitive_convertible?(long, long)
    assert primitive_convertible?(long, float)
    assert primitive_convertible?(long, double)

    assert !primitive_convertible?(float, boolean)
    assert !primitive_convertible?(float, byte)
    assert !primitive_convertible?(float, short)
    assert !primitive_convertible?(float, char)
    assert !primitive_convertible?(float, int)
    assert !primitive_convertible?(float, long)
    assert primitive_convertible?(float, float)
    assert primitive_convertible?(float, double)

    assert !primitive_convertible?(double, boolean)
    assert !primitive_convertible?(double, byte)
    assert !primitive_convertible?(double, short)
    assert !primitive_convertible?(double, char)
    assert !primitive_convertible?(double, int)
    assert !primitive_convertible?(double, long)
    assert !primitive_convertible?(double, float)
    assert primitive_convertible?(double, double)
  end

  def test_primitive_array
    ary = @types.type(nil, 'byte', true)
    int = @types.type(nil, 'int')

    # TODO fix intrinsics
    assert_equal(@types.type(nil, 'byte'), method_type(ary, "[]", [int]).resolve)
  end


  def test_primitive_not_convertible_to_array_with_same_component_type
    ary = @types.type(nil, 'byte', true)
    byte = @types.type(nil, 'byte')

    assert !primitive_convertible?(byte, ary)
  end

  def test_int
    ast = parse("#{1 << 16}")
    assert_equal(@types.type(nil, 'int'), inferred_type(ast))
  end

  def test_long
    ast = parse("#{1 << 33}")
    assert_equal(@types.type(nil, 'long'), inferred_type(ast))
  end
  
  def test_char
    ast = parse("?a")
    assert_equal(@types.type(nil, 'char'), inferred_type(ast))
  end

  def test_static_method
    ast = parse("class Foo;def self.bar; 1; end; end; Foo.bar")
    assert_equal(@types.type(nil, 'int'), inferred_type(ast))
  end
end
