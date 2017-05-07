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
      x.add "1"
      x[0]= "2"
      x[0]= "3"
      puts x
    EOF
    assert_run_output("[3]\n", cls)
  end

  def test_bracket_out_of_range_exception_at_assign
    java_import 'java.lang.IndexOutOfBoundsException'
    cls, = compile(<<-EOF)
      import java.util.ArrayList
      x = ArrayList.new
      x[0]= "2"
      puts x
    EOF
    begin
     assert_run_output("xxxx", cls)
     fail "should rise IndexOutOfBoundsException"
    rescue IndexOutOfBoundsException => ex
    end
  end

  def test_sort_with_block
    cls, = compile(<<-EOF)
      puts ([3,1,2].sort do |o0:Comparable,o1:Comparable|
        -o0.compareTo(o1)
      end)
    EOF
    assert_run_output("[3, 2, 1]\n", cls)
  end

  def test_sort_bang_with_block
    cls, = compile(<<-EOF)
      puts ([3,1,2].sort! do |o0:Comparable,o1:Comparable|
        -o0.compareTo(o1)
      end)
    EOF
    assert_run_output("[3, 2, 1]\n", cls)
  end

  def test_sort_with_comparator
    cls, = compile(<<-EOF)
      class Co implements java::util::Comparator
        def compare(o0:Object,o1:Object)
          compare(Comparable(o0),Comparable(o1))
        end
        def compare(o0:Comparable,o1:Comparable)
          -o0.compareTo(o1)
        end
      end
      puts [3,1,2].sort(Co.new)
    EOF
    assert_run_output("[3, 2, 1]\n", cls)
  end

  def test_sort_bang_with_comparator
    cls, = compile(<<-EOF)
      class Co implements java::util::Comparator
        def compare(o0:Object,o1:Object)
          compare(Comparable(o0),Comparable(o1))
        end
        def compare(o0:Comparable,o1:Comparable)
          -o0.compareTo(o1)
        end
      end
      puts [3,1,2].sort!(Co.new)
    EOF
    assert_run_output("[3, 2, 1]\n", cls)
  end

  def test_sort_without_comparator
    cls, = compile(<<-EOF)
      puts [5,1,3].sort
    EOF
    assert_run_output("[1, 3, 5]\n", cls)
  end

  def test_first
    cls, = compile(<<-EOF)
      puts [5,1,3].first
    EOF
    assert_run_output("5\n", cls)
  end

  def test_empty_list_first
    cls, = compile(<<-EOF)
      puts [].first
    EOF
    assert_run_output("null\n", cls)
  end

  def test_last
    cls, = compile(<<-EOF)
      puts [5,1,3].last
    EOF
    assert_run_output("3\n", cls)
  end

  def test_empty_list_last
    cls, = compile(<<-EOF)
      puts [].last
    EOF
    assert_run_output("null\n", cls)
  end

  def test_first!
    cls, = compile(<<-EOF)
      puts [5,1,3].first!
    EOF
    assert_run_output("5\n", cls)
  end

  def test_empty_list_first!
    cls, = compile(<<-EOF)
      puts [].first!
    EOF
    assert_raise_java(java.lang.IndexOutOfBoundsException) do
      cls.main nil
    end
  end

  def test_last!
    cls, = compile(<<-EOF)
      puts [5,1,3].last!
    EOF
    assert_run_output("3\n", cls)
  end

  def test_empty_list_last!
    cls, = compile(<<-EOF)
      puts [].last!
    EOF
    assert_raise_java(java.lang.ArrayIndexOutOfBoundsException) do
      cls.main nil
    end
  end
  
  def test_array_as_type
    cls, = compile(<<-EOF)
      a = [5,1,3].as(short[])
      puts a.getClass.getName
      puts a.join(",")
      b = ["foo","bar"].as(String[])
      puts b.getClass.getName
      puts b.join(",")
    EOF
    assert_run_output("[S\n5,1,3\n[Ljava.lang.String;\nfoo,bar\n", cls)
  end

  def test_array_as_fully_qualified_type_colon2
    cls, = compile(<<-EOF)
      a = [5,7,4].as(java::lang::Integer[])
      puts a.getClass.getName
      puts a.join(",")
    EOF
    assert_run_output("[Ljava.lang.Integer;\n5,7,4\n", cls)
  end

  def test_array_as_fully_qualified_type_dot1
    pend "Using a fully qualified type literal concatenated by dots as macro parameter is currently broken" do 
      cls, = compile(<<-EOF)
        a = [8,2,7].as(java.lang.Integer[])
        puts a.getClass.getName
        puts a.join(",")
      EOF
      assert_run_output("[Ljava.lang.Integer;\n8,2,7\n", cls)
    end
  end
end
