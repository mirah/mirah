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
  
  def test_sort_with_comparator
    cls, = compile(<<-EOF)
      class Co implements java::util::Comparator
        def compare(o0:Object,o1:Object)
          compare(Comparable(o0),Comparable(o1))
        end
        def compare(o0:Comparable,o1:Comparable)
          o0.compareTo(o1)
        end
      end
      puts [3,1,2].sort(Co.new)
    EOF
    assert_run_output("[1, 2, 3]\n", cls)
  end

  def test_sort_without_comparator
    cls, = compile(<<-EOF)
      puts [5,1,3].sort
    EOF
    assert_run_output("[1, 3, 5]\n", cls)
  end

end
