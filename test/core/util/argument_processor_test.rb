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
  java_import 'org.mirah.tool.MirahArguments'
  def test_arg_dash_v_prints_version_and_has_exit_0
    arg_processor = MirahArguments.new

    assert_output "Mirah v#{Mirah::VERSION}\n" do
      arg_processor.apply_args(["-v"])
    end

    assert arg_processor.exit?
    assert_equal 0, arg_processor.exit_status
  end


  def test_on_invalid_arg_prints_error_and_exits_1
    arg_processor = MirahArguments.new

    assert_output "Unrecognized flag: --some-arg\n" do
      arg_processor.apply_args(["--some-arg"])
    end

    assert arg_processor.exit?
    assert_equal 1, arg_processor.exit_status
  end

  def test_arg_bootclasspath_sets_bootclasspath_with_absolute_paths
    path = "class:path"
    arg_processor = MirahArguments.new
    
    arg_processor.apply_args ["--bootclasspath", path]

    assert_equal path.split(":").map{|p|"file:%s" % File.expand_path(p) }.join(":"),
                 arg_processor.real_bootclasspath.map{|u| u.to_s }.join(":")
  end

  def test_dash_h_prints_help_and_exits
    arg_processor = MirahArguments.new

    usage_message = capture_output do
      arg_processor.apply_args  ["-h"]
    end

    assert usage_message.include? 'mirahc [flags] <files or -e SCRIPT>'
    assert usage_message.include? '-h, --help'

    assert arg_processor.exit?
    assert_equal 0, arg_processor.exit_status
  end
end
