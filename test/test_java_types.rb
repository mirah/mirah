require 'test/unit'
require 'rr'
require 'duby/jvm/types'
require 'duby/jvm/compiler'

class TestTypes < Test::Unit::TestCase
  include RR::Adapters::TestUnit
  include Duby::Compiler::JVM::Types

  def test_newarray
    Boolean.newarray(mock!.newbooleanarray.subject)
    Byte.newarray(mock!.newbytearray.subject)
    Char.newarray(mock!.newchararray.subject)
    Short.newarray(mock!.newshortarray.subject)
    Int.newarray(mock!.newintarray.subject)
    Long.newarray(mock!.newlongarray.subject)
    Float.newarray(mock!.newfloatarray.subject)
    Double.newarray(mock!.newdoublearray.subject)
    Object.newarray(mock!.anewarray(Object).subject)
    String.newarray(mock!.anewarray(String).subject)
  end
end

class TestCompilerUsesTypes < Test::Unit::TestCase
  include RR::Adapters::TestUnit
  include Duby
  import java.lang.System

  def setup
    @compiler = Compiler::JVM.new("script" + System.nano_time.to_s)
  end

  def test_emptyarray_uses_types
    ast = mock!.compile(@compiler, false) {
      count = Object.new
      mock(@compiler.method).ldc(count)
      type = mock!.newarray(@compiler.method).subject
      mock(@compiler).mapped_type(type) {type}
      @compiler.empty_array(type, count)
    }
    @compiler.define_main(ast.subject)
  end
end