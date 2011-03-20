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

$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'mirah'

class TestJavaTyper < Test::Unit::TestCase
  include Mirah

  def setup
    AST.type_factory = Mirah::JVM::Types::TypeFactory.new
    @typer = Typer::JVM.new(nil)
    compiler = Mirah::Compiler::JVM.new

    @java_typer = Typer::JavaTyper.new
  end

  def teardown
    AST.type_factory = nil
  end

  def test_simple_overtyped_meta_method
    string_meta = AST.type(nil, 'java.lang.String', false, true)
    string = AST.type(nil, 'java.lang.String')

    # integral types
    ['boolean', 'char', 'double', 'float', 'int', 'long'].each do |type_name|
      type = AST.type(nil, type_name)
      return_type = @java_typer.method_type(@typer, string_meta, 'valueOf', [type])
      assert_equal(string, return_type, "valueOf(#{type}) should return #{string}")
    end

    # char[]
    type = AST.type(nil, 'char', true)
    return_type = @java_typer.method_type(@typer, string_meta, 'valueOf', [type])
    assert_equal(string, return_type)

    # Object
    type = AST.type(nil, 'java.lang.Object')
    return_type = @java_typer.method_type(@typer, string_meta, 'valueOf', [type])
    assert_equal(string, return_type)
  end

  def test_non_overtyped_method
    string = AST.type(nil, 'java.lang.String')

    int = AST.type(nil, 'int')
    return_type = @java_typer.method_type(@typer, string, 'length', [])
    assert_equal(int, return_type)

    byte_array = AST.type(nil, 'byte', true)
    return_type = @java_typer.method_type(@typer, string, 'getBytes', [])
    assert_equal(byte_array, return_type)
  end

  def test_simple_overtyped_method
    string_meta = AST.type(nil, 'java.lang.String', false, true)
    string = AST.type(nil, 'java.lang.String')

    return_type = @java_typer.method_type(@typer, string_meta, 'valueOf', [string])
    assert_equal(string, return_type)
  end

  def test_primitive_conversion_method
    string = AST.type(nil, 'java.lang.String')
    byte = AST.type(nil, 'byte')
    char = AST.type(nil, 'char')
    long = AST.type(nil, 'long')

    return_type = @java_typer.method_type(@typer, string, 'charAt', [byte])
    assert_equal(char, return_type)

    assert_raise NoMethodError do
      @java_typer.method_type(@typer, string, 'charAt', [long])
    end
  end

  include Mirah::JVM::MethodLookup

  def test_is_more_specific
    object = java.lang.Object.java_class
    charseq = java.lang.CharSequence.java_class
    string = java.lang.String.java_class

    assert @java_typer.is_more_specific?([string], [object])
    assert @java_typer.is_more_specific?([charseq], [object])
    assert @java_typer.is_more_specific?([string], [charseq])
  end

  def test_primitive_convertible
    boolean = Mirah::JVM::Types::Boolean
    byte = Mirah::JVM::Types::Byte
    short = Mirah::JVM::Types::Short
    char = Mirah::JVM::Types::Char
    int = Mirah::JVM::Types::Int
    long = Mirah::JVM::Types::Long
    float = Mirah::JVM::Types::Float
    double = Mirah::JVM::Types::Double

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
    ary = AST.type(nil, 'byte', true)
    int = AST.type(nil, 'int')

    java_typer = Typer::JavaTyper.new

    assert_equal(AST.type(nil, 'byte'), java_typer.method_type(nil, ary, "[]", [int]))
  end

  def test_int
    ast = AST.parse("#{1 << 16}")
    assert_equal(AST.type(nil, 'int'), ast.infer(@typer, true))
  end

  def test_long
    ast = AST.parse("#{1 << 33}")
    assert_equal(AST.type(nil, 'long'), ast.infer(@typer, true))
  end
  
  def test_dynamic_assignability
    ast = AST.parse("a = 1; a = dynamic('foo')")
    assert_equal :error, ast.infer(@typer, true).name
    
    ast = AST.parse("a = Object.new; a = dynamic('foo')")
    assert_equal 'java.lang.Object', ast.infer(@typer, true).name
  end
end
