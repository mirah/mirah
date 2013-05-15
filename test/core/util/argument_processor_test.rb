# Copyright (c) 2013 The Mirah project authors. All Rights Reserved.
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

  def test_arg_bootclasspath_sets_bootclasspath_on_compilation_state
    path = "class:path"
    state = Mirah::Util::CompilationState.new
    processor = Mirah::Util::ArgumentProcessor.new state, ["--bootclasspath", path]
    processor.process

    assert_equal path, state.bootclasspath
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
end
