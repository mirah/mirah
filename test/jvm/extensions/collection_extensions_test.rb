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

  def test_mirah_array_join_separator_empty
    cls, = compile(<<-EOF)
      x = [].join(",")
      puts x
    EOF
    assert_run_output("\n", cls)
  end

  def test_mirah_array_join_separator_single
    cls, = compile(<<-EOF)
      x = ["a"].join(",")
      puts x
    EOF
    assert_run_output("a\n", cls)
  end

  def test_mirah_array_join_separator_multiple
    cls, = compile(<<-EOF)
      x = ["a",1,"c"].join(",")
      puts x
    EOF
    assert_run_output("a,1,c\n", cls)
  end

  def test_java_array_join_separator_empty
    cls, = compile(<<-EOF)
      x = int[0].join(",")
      puts x
    EOF
    assert_run_output("\n", cls)
  end

  def test_java_array_join_separator_single
    cls, = compile(<<-EOF)
      x = ["a"].to_a(String).join(",")
      puts x
    EOF
    assert_run_output("a\n", cls)
  end

  def test_java_array_join_separator_multiple
    cls, = compile(<<-EOF)
      x = ["a",1,"c"].to_a(Object).join(",")
      puts x
    EOF
    assert_run_output("a,1,c\n", cls)
  end

  def test_primitve_java_array_join_separator_multiple
    cls, = compile(<<-EOF)
      x = int[4].join(",")
      puts x
    EOF
    assert_run_output("0,0,0,0\n", cls)
  end

  # implicitly tests each_with_index
  def test_mapa_on_list
    cls, = compile(%q[
      x = ["a","b","c","d"].mapa do |s|
        "#{s}x"
      end
      puts x[2]
      puts x.getClass.getName
    ])
    assert_run_output("cx\n[Ljava.lang.String;\n", cls)
  end

  # implicitly tests each_with_index
  def test_mapa_on_java_array_with_complex_basetype
    cls, = compile(%q[
      x = ["a","b","c","d"].to_a(String).mapa do |s|
        "#{s}x"
      end
      puts x[2]
      puts x.getClass.getName
    ])
    assert_run_output("cx\n[Ljava.lang.String;\n", cls)
  end

  # implicitly tests each_with_index
  def test_mapa_on_java_array_with_primitive_basetype
    cls, = compile(%q[
      x = [1,2,3,4].to_a(int).mapa do |s|
        "#{s}x"
      end
      puts x[2]
      puts x.getClass.getName
    ])
    assert_run_output("3x\n[Ljava.lang.String;\n", cls)
  end

  def test_map
    cls, = compile(%q[
      x = ["a","b","c","d"].map do |s|
        "#{s}x"
      end
      puts x[2]
      puts x.getClass.getName
    ])
    assert_run_output("cx\njava.util.ArrayList\n", cls)
  end

  def test_operator_append
    cls, = compile(%q{
      x = ["a"]
      x << "b"
      x << "c" << "d"
      x << "e"
      puts x
    })
    assert_run_output("[a, b, c, d, e]\n", cls)
  end
end

