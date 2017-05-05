class ArrayExtensionsTest < Test::Unit::TestCase

  def test_equals
    cls, = compile(<<-EOF)
      a = int[3]
      a[2] = 4
      b = int[3]
      b[2] = 4
      puts a==b # true
      
      b[1] = 3
      puts a==b # false, because contents are not equal
      
      c = Object[2]
      d = String[2]
      c[0] = "a"
      c[1] = "1"
      d[0] = "a"
      d[1] = "#{1}"
      puts c==d # true, although the classes of the arrays are different, the contents are equal
    EOF
    assert_run_output("true\nfalse\ntrue\n", cls)
  end

  def test_empty_q
    cls, = compile(<<-EOF)
      x = int[0]
      puts x.empty?
    EOF
    assert_run_output("true\n", cls)
  end

  def test_bracket_getter
    cls, = compile(<<-EOF)
      x = int[2]
      x[0] = 1
      x[1] = 2
      puts x[0]
    EOF
    assert_run_output("1\n", cls)
  end

  def test_bracket_assignment
    cls, = compile(<<-EOF)
      x = String[1]
      x[0]= "2"
      puts java::util::Arrays.toString(x)
    EOF
    assert_run_output("[2]\n", cls)
  end
  
  def test_size
    cls, = compile(%q{
      puts int[4].size
    })
    assert_run_output("4\n", cls)
  end
  
  def test_each_with_index
    cls, = compile(%q{
      x = int[3]
      x[0] = 9
      x[1] = 7
      x[2] = 5
      x.each_with_index do |value,index|
        puts "#{value} #{index}"
      end
    })
    assert_run_output("9 0\n7 1\n5 2\n", cls)
  end
  
  def test_sort_with_comparator_block # comparators are only support for non-primitive types
    cls, = compile(%q{
      x = Integer[3]
      x[0] = 3
      x[1] = 1
      x[2] = 2
      y = x.sort do |a:Integer,b:Integer|
        -(a.intValue-b.intValue)
      end
      puts java::util::Arrays.toString(y)
    })
    assert_run_output("[3, 2, 1]\n", cls)
  end

  def test_sort_without_comparator
    cls, = compile(<<-EOF)
      x = int[3]
      x[0] = 5
      x[1] = 1
      x[2] = 3
      puts java::util::Arrays.toString(x.sort)
    EOF
    assert_run_output("[1, 3, 5]\n", cls)
  end

  def test_first!
    cls, = compile(<<-EOF)
      x = int[3]
      x[0] = 5
      x[1] = 1
      x[2] = 3
      puts x.first!
    EOF
    assert_run_output("5\n", cls)
  end

  def test_empty_array_first!
    cls, = compile(<<-EOF)
      x = int[0]
      puts x.first!
    EOF
    assert_raise_java(java.lang.ArrayIndexOutOfBoundsException) do
      cls.main nil
    end
  end

  def test_last!
    cls, = compile(<<-EOF)
      x = int[3]
      x[0] = 5
      x[1] = 1
      x[2] = 3
      puts x.last!
    EOF
    assert_run_output("3\n", cls)
  end

  def test_empty_array_last!
    cls, = compile(<<-EOF)
      x = int[0]
      puts x.last!
    EOF
    assert_raise_java(java.lang.ArrayIndexOutOfBoundsException) do
      cls.main nil
    end
  end
  
  def test_array_join
    cls, = compile(<<-EOF)
      x = int[3]
      x[0] = 5
      x[1] = 1
      x[2] = 3
      puts x.join(':')
    EOF
    assert_run_output("5:1:3\n", cls)
  end
  
  def test_array_join_empty
    cls, = compile(<<-EOF)
      x = int[0]
      puts x.join(':')
    EOF
    assert_run_output("\n", cls)
  end
  
  def test_array_join_single
    cls, = compile(<<-EOF)
      x = int[1]
      x[0] = 4
      puts x.join(':')
    EOF
    assert_run_output("4\n", cls)
  end
  
  def test_array_join_direct
    cls, = compile(<<-EOF)
      x = int[3]
      x[0] = 5
      x[1] = 1
      x[2] = 3
      puts x.join
    EOF
    assert_run_output("513\n", cls)
  end
  
  def test_array_join_direct_empty
    cls, = compile(<<-EOF)
      x = int[0]
      puts x.join
    EOF
    assert_run_output("\n", cls)
  end
  
  def test_array_join_direct_single
    cls, = compile(<<-EOF)
      x = int[1]
      x[0] = 4
      puts x.join
    EOF
    assert_run_output("4\n", cls)
  end
  
  def test_int_array_new
    cls, = compile(<<-EOF)
      x = int[].new(5)
      puts x.join(",")
    EOF
    assert_run_output("0,0,0,0,0\n", cls)
  end

  def test_ArrayList_array_new
    cls, = compile(<<-EOF)
      x = java::util::ArrayList[].new(5)
      puts x.join(",")
    EOF
    assert_run_output("null,null,null,null,null\n", cls)
  end

  def test_array_new
    cls, = compile(<<-EOF)
      x = int[].new(5) do |i|
        i*2+1
      end
      puts x.join(",")
    EOF
    assert_run_output("1,3,5,7,9\n", cls)
  end
end
