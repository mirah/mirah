require 'test_helper'

class ArgumentProcessorTest < Test::Unit::TestCase

  def test_arg_dash_v_prints_version_and_has_exit_0
    state = Mirah::Util::CompilationState.new
    processor = Mirah::Util::ArgumentProcessor.new state, ["-v"]

    assert_output "Mirah v#{Mirah::VERSION}\n" do
      processor.process
    end

    assert processor.exit?
    assert_equal 0, processor.exit_status_code
  end


  def test_on_invalid_arg_prints_error_and_exits_1
    state = Mirah::Util::CompilationState.new
    processor = Mirah::Util::ArgumentProcessor.new state, ["--some-arg"]

    assert_output "unrecognized flag: --some-arg\n" do
      processor.process
    end

    assert processor.exit?
    assert_equal 1, processor.exit_status_code
  end

#  def test_arg_bootclasspath_sets_bootclasspath_on_type_factory_ugh
#    Mirah::AST.type_factory = Mirah::JVM::Types::TypeFactory.new # global state grumble grumble
#
#    path = "class:path"
#    state = Mirah::Util::CompilationState.new
#    processor = Mirah::Util::ArgumentProcessor.new state, ["--bootclasspath", path]
#    processor.process
#
#    assert_equal path, Mirah::AST.type_factory.bootclasspath
#  end

  def test_dash_j_fails_when_not_compiling
    state = Mirah::Util::CompilationState.new
    processor = Mirah::Util::ArgumentProcessor.new state, ["-j"]

    assert_output "-j/--java flag only applies to \"compile\" mode.\n" do
      processor.process
    end

    assert processor.exit?
    assert_equal 1, processor.exit_status_code
  end

  def test_dash_h_prints_help_and_exits
    state = Mirah::Util::CompilationState.new
    processor = Mirah::Util::ArgumentProcessor.new state, ["-h"]

    assert_output processor.help_message + "\n" do
      processor.process
    end

    assert processor.exit?
    assert_equal 0, processor.exit_status_code
  end

  def test_arg_bootclasspath_sets_bootclasspath_on_type_factory_ugh
    Mirah::AST.type_factory = Mirah::JVM::Types::TypeFactory.new # global state grumble grumble

    path = "class:path"
    state = Mirah::Util::CompilationState.new
    processor = Mirah::Util::ArgumentProcessor.new state, ["--bootclasspath", path]
    processor.process

    assert_equal path, Mirah::AST.type_factory.bootclasspath
  end
end
