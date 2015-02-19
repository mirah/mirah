class ListExtensionsTest < Test::Unit::TestCase
  def test_empty_q
    cls, = compile(<<-EOF)
      x = []
      puts x.empty?
    EOF
    assert_run_output("true\n", cls)
  end

  def test_bracket_getter
    cls, = compile(<<-EOF)
      x = [1,2]
      puts x[0]
    EOF
    assert_run_output("1\n", cls)
  end

  def test_bracket_assignment
    cls, = compile(<<-EOF)
      import java.util.ArrayList
      x = ArrayList.new
      x[0]= "2"
      puts x
    EOF
    assert_run_output("[2]\n", cls)
  end
end
