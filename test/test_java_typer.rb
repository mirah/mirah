$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'duby/typer'
require 'duby/plugin/java'
require 'duby/jvm/compiler'
require 'duby/jvm/typer'

class TestJavaTyper < Test::Unit::TestCase
  include Duby
  
  def setup
    AST.type_factory = Duby::JVM::TypeFactory.new
    compiler = Duby::Compiler::JVM.new('foobar')
    @typer = Typer::JVM.new(compiler)
    
    @java_typer = Typer::JavaTyper.new
  end

  def teardown
    AST.type_factory = nil
  end

  def test_simple_overtyped_meta_method
    string_meta = AST::type('java.lang.String', false, true)
    string = AST::type('java.lang.String')
    
    # integral types
    ['boolean', 'char', 'double', 'float', 'int', 'long'].each do |type_name|
      type = AST::type(type_name)
      return_type = @java_typer.method_type(@typer, string_meta, 'valueOf', [type])
      assert_equal(string, return_type, "valueOf(#{type}) should return #{string}")
    end
    
    # char[]
    type = AST::type('char', true)
    return_type = @java_typer.method_type(@typer, string_meta, 'valueOf', [type])
    assert_equal(string, return_type)
    
    # Object
    type = AST::type('java.lang.Object')
    return_type = @java_typer.method_type(@typer, string_meta, 'valueOf', [type])
    assert_equal(string, return_type)
  end
  
  def test_non_overtyped_method
    string = AST::type('java.lang.String')
    
    int = AST::type('int')
    return_type = @java_typer.method_type(@typer, string, 'length', [])
    assert_equal(int, return_type)
    
    byte_array = AST::type('byte', true)
    return_type = @java_typer.method_type(@typer, string, 'getBytes', [])
    assert_equal(byte_array, return_type)
  end
  
  def test_simple_overtyped_method
    string_meta = AST::type('java.lang.String', false, true)
    string = AST::type('java.lang.String')
    
    return_type = @java_typer.method_type(@typer, string_meta, 'valueOf', [string])
    assert_equal(string, return_type)
  end
  
  def test_primitive_conversion_method
    string = AST::type('java.lang.String')
    byte = AST::type('byte')
    char = AST::type('char')
    long = AST::type('long')
    
    return_type = @java_typer.method_type(@typer, string, 'charAt', [byte])
    assert_equal(char, return_type)
    
    l = lambda {@java_typer.method_type(@typer, string, 'charAt', [long])}
    l.should raise_error NoMethodError
  end
  
  include Duby::JVM::MethodLookup
  
  def test_complex_overtyped_method
    printstream = java.io.PrintStream.java_class
    object = java.lang.Object.java_class
    string = java.lang.String.java_class
    
    # best match is Object
    method = find_method(printstream, "println", [object], false)
    assert_match('println(java.lang.Object)', method.to_s)
    # best match is String
    method = find_method(printstream, "println", [string], false)
    assert_match('println(java.lang.String)', method.to_s)
    # only match is Object
    method = find_method(printstream, "println", [printstream], false)
    assert_match('println(java.lang.Object)', method.to_s)
  end
  
  def test_is_more_specific
    object = java.lang.Object.java_class
    charseq = java.lang.CharSequence.java_class
    string = java.lang.String.java_class
    
    assert @java_typer.is_more_specific?([string], [object])
    assert @java_typer.is_more_specific?([charseq], [object])
    assert @java_typer.is_more_specific?([string], [charseq])
  end
  
  def test_primitive_convertible
    boolean = Java::boolean.java_class
    byte = Java::byte.java_class
    short = Java::short.java_class
    char = Java::char.java_class
    int = Java::int.java_class
    long = Java::long.java_class
    float = Java::float.java_class
    double = Java::double.java_class
    
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
    assert primitive_convertible?(byte, char)
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
    assert !primitive_convertible?(long, float)
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
    ary = AST.type('byte', true)
    int = AST.type('int')

    java_typer = Typer::JavaTyper.new

    assert_equal(AST.type('byte'), java_typer.method_type(nil, ary, "[]", [int]))
  end
end
