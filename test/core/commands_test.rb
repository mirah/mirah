# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
# All contributing project authors may be found in the NOTICE file.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'test_helper'


class CommandsTest < Test::Unit::TestCase
  def teardown
    Mirah::AST.type_factory = nil
  end
  
  class RaisesMirahErrorCommand < Mirah::Commands::Base
    def execute
      execute_base { raise Mirah::MirahError, "just an error" }
    end
    def command_name; :foo; end
  end
  
  class MirahProcessesErrorCommand < Mirah::Commands::Base
    include  Mirah::Util::ProcessErrors
    def execute
      execute_base { process_errors [Mirah::NodeError.new("just an error")] }
    end
    def command_name; :foo; end
  end
  
  class SuccessfulCommand < Mirah::Commands::Base
    def execute
      execute_base { "something" }
    end
    def command_name; :foo; end
  end

  def test_on_Mirah_error_has_non_zero_exit_code
    assert_non_zero_exit do
      RaisesMirahErrorCommand.new([]).execute
    end
  end

  def test_on_bad_argument_has_non_zero_exit_code
    assert_non_zero_exit do
      RaisesMirahErrorCommand.new(['-bad-argument']).execute
    end
  end
  
  def test_on_v_with_no_args_exits_without_running_command
    assert_zero_exit do
      RaisesMirahErrorCommand.new(['-v']).execute
    end
  end
    
  def test_on_j_option_when_command_is_not_compile_has_non_zero_exit_code
    assert_non_zero_exit do
      RaisesMirahErrorCommand.new(['-j']).execute
    end
  end
  
  def test_success_is_truthy
    assert SuccessfulCommand.new([]).execute, "expected it to be truthy"
  end
  
  def test_process_errors_causes_a_non_zero_exit
    assert_non_zero_exit do
      MirahProcessesErrorCommand.new([]).execute
    end
  end

  def test_run_says_no_main_and_exits_with_non_zero_with_no_main
    cmd = Mirah::Commands::Run.new([])

    #stub class generation, loading, return nil main
    def cmd.load_classes_and_find_main *args;nil;end
    def cmd.generate_class_map;end

    assert_non_zero_exit do
      assert_output "No main found\n" do
        cmd.execute
      end
    end
  end

  def assert_non_zero_exit
    ex = assert_raise SystemExit do
      yield
    end
    assert_not_equal 0, ex.status
  end

  def assert_zero_exit
    ex = assert_raise SystemExit do
      yield
    end
    assert_equal 0, ex.status
  end

end
