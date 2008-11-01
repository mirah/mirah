require 'test/unit'
require 'duby'
require 'duby/plugin/math'

class TestMathPlugin < Test::Unit::TestCase
  include Duby

  def setup
    @typer = Typer::Simple.new :bar
  end

  def assert_resolves_to(type, script)
    ast = AST.parse("1 + 1")
    ast.infer(@typer)
    assert_nothing_raised {@typer.resolve(true)}
    assert_equal(@typer.fixnum_type, ast.inferred_type)
  end
  
  def test_plus
    assert_resolves_to(@typer.fixnum_type, '1 + 1')
    assert_resolves_to(@typer.float_type, '1.0 + 1.0')
  end
  
  def test_minus
    assert_resolves_to(@typer.fixnum_type, '1 - 1')
    assert_resolves_to(@typer.float_type, '1.0 - 1.0')
  end
  
  def test_times
    assert_resolves_to(@typer.fixnum_type, '1 * 1')
    assert_resolves_to(@typer.float_type, '1.0 * 1.0')
  end
  
  def test_divide
    assert_resolves_to(@typer.fixnum_type, '1 / 1')
    assert_resolves_to(@typer.float_type, '1.0 / 1.0')
  end

  def test_remainder
    assert_resolves_to(@typer.fixnum_type, '1 % 1')
    assert_resolves_to(@typer.float_type, '1.0 % 1.0')
  end

  def test_shift_left
    assert_resolves_to(@typer.fixnum_type, '1 << 1')
  end

  def test_shift_right
    assert_resolves_to(@typer.fixnum_type, '1 >> 1')
  end

  def test_ushift_right
    assert_resolves_to(@typer.fixnum_type, '1 >>> 1')
  end

  def test_bitwise_and
    assert_resolves_to(@typer.fixnum_type, '1 & 1')
  end

  def test_bitwise_or
    assert_resolves_to(@typer.fixnum_type, '1 | 1')
  end

  def test_bitwise_xor
    assert_resolves_to(@typer.fixnum_type, '1 ^ 1')
  end

  def test_less_than
    assert_resolves_to(@typer.boolean_type, '1 < 1')
    assert_resolves_to(@typer.boolean_type, '1.0 < 1.0')
  end

  def test_greater_than
    assert_resolves_to(@typer.boolean_type, '1 > 1')
    assert_resolves_to(@typer.boolean_type, '1.0 > 1.0')
  end

  def test_less_than_or_equal
    assert_resolves_to(@typer.boolean_type, '1 <= 1')
    assert_resolves_to(@typer.boolean_type, '1.0 <= 1.0')
  end

  def test_greater_than_or_equal
    assert_resolves_to(@typer.boolean_type, '1 >= 1')
    assert_resolves_to(@typer.boolean_type, '1.0 >= 1.0')
  end
end