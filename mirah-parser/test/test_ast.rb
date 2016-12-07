require 'test/unit'
require 'java'

$CLASSPATH << 'dist/mirah-parser.jar'

class TestAst < Test::Unit::TestCase
  java_import 'mirah.lang.ast.VCall'
  java_import 'mirah.lang.ast.FunctionalCall'
  java_import 'mirah.lang.ast.PositionImpl'
  java_import 'mirah.lang.ast.StringCodeSource'
  java_import 'mirah.lang.ast.SimpleString'

  def test_vcall_target_has_parent
    call = VCall.new some_position
    assert_equal call, call.target.parent
  end

  def test_functional_call_target_has_parent
    call = FunctionalCall.new some_position
    assert_equal call, call.target.parent
  end

  def some_position
    PositionImpl.new(StringCodeSource.new('blah', 'codegoeshere'), 0, 0, 0, 1, 0, 1)
  end
end
