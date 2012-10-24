class MainMethodTest < Test::Unit::TestCase
  def test_main_generation_for_file_with_class_of_same_name
    code = <<-EOC
      class WithMain
      end
      System.out.println 'bar'
    EOC

    main_class, = compile code, 'with_main'

    assert_output "bar\n" do
      main_class.main(nil)
    end
  end
end
