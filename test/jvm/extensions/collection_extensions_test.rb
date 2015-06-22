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

end

