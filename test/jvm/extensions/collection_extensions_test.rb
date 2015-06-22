class CollectionExtensionsTest < Test::Unit::TestCase
  def test_mirah_array_join_empty
    cls, = compile(<<-EOF)
      x = [].join
      puts x
    EOF
    assert_run_output("\n", cls)
  end

  def test_mirah_array_join_single
    cls, = compile(<<-EOF)
      x = ["a"].join
      puts x
    EOF
    assert_run_output("a\n", cls)
  end

  def test_mirah_array_join_multiple
    cls, = compile(<<-EOF)
      x = ["a",1,"c"].join
      puts x
    EOF
    assert_run_output("a1c\n", cls)
  end

  def test_java_array_join_empty
    cls, = compile(<<-EOF)
      x = int[0].join
      puts x
    EOF
    assert_run_output("\n", cls)
  end

  def test_java_array_join_single
    cls, = compile(<<-EOF)
      x = ["a"].to_a(String).join
      puts x
    EOF
    assert_run_output("a\n", cls)
  end

  def test_java_array_join_multiple
    cls, = compile(<<-EOF)
      x = ["a",1,"c"].to_a(Object).join
      puts x
    EOF
    assert_run_output("a1c\n", cls)
  end

  def test_primitve_java_array_join_multiple
    cls, = compile(<<-EOF)
      x = int[4].join
      puts x
    EOF
    assert_run_output("0000\n", cls)
  end

end

