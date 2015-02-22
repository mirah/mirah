class NumericExtensionsTest < Test::Unit::TestCase
  def test_power_macro
    cls, = compile(<<-EOF)
      def run(n1:int, n2:int)
        puts n1 ** n2
      end
    EOF

    assert_output("16.0\n") do
      cls.run(4, 2)
    end
  end
end
