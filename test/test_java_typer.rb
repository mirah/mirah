$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'duby/typer'
require 'duby/plugin/java'

class TestJavaTyper < Test::Unit::TestCase
  include Duby
  
  def setup
    @typer = Typer::Simple.new :foo
    @typer.known_types[AST::type('string')] = AST::type('java.lang.String')
    @typer.known_types[AST::type('string', false, true)] = AST::type('java.lang.String', false, true)
    
    @java_typer = Typer::JavaTyper.new
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
  
  def test_overtyped_method
    string_meta = AST::type('java.lang.String', false, true)
    string = AST::type('java.lang.String')
    
    return_type = @java_typer.method_type(@typer, string_meta, 'valueOf', [string])
    assert_equal(string, return_type)
  end
end
