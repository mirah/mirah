require 'test_helper'

class ArgumentProcessorTest < Test::Unit::TestCase

  def test_arg_dash_v_prints_version_and_exits_0
    state = Mirah::Util::CompilationState.new
    processor = Mirah::Util::ArgumentProcessor.new state, ["-v"]
    status_code = catch :exit do
      assert_output "Mirah v#{Mirah::VERSION}" do
        processor.process
      end
    end

    assert_equal 0, status_code
  end
end
