# Copyright (c) 2013-2014 The Mirah project authors. All Rights Reserved.
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

class MirahArgumentsTest < Test::Unit::TestCase
  java_import 'org.mirah.tool.MirahArguments'
  java_import 'java.io.File'
  
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
    path = Mirah::Env.encode_paths %w[class path]
    arg_processor = MirahArguments.new
    
    arg_processor.apply_args ["--bootclasspath", path]

    assert_equal_classpaths path,
                 arg_processor.real_bootclasspath
  end

  def test_flag_classpath_overrides_env
    env = { "CLASSPATH" => Mirah::Env.encode_paths(%w[some classpath]) }
            
    path = Mirah::Env.encode_paths %w[class path]
    
    arg_processor = MirahArguments.new env
    arg_processor.apply_args ["--classpath", path]

    assert_equal_classpaths path,
                 arg_processor.real_classpath
  end

  def test_classpath_is_from_env_without_flag
    path = Mirah::Env.encode_paths %w[class path]
    env = { "CLASSPATH" => path }
    
    arg_processor = MirahArguments.new env
    arg_processor.apply_args []

    assert_equal_classpaths path,
                 arg_processor.real_classpath
  end

  def test_classpath_defaults_to_cwd
    arg_processor = MirahArguments.new({})
    arg_processor.apply_args []

    assert_equal_classpaths ".",
                 arg_processor.real_classpath
  end

  def test_classpath_is_destination_when_no_flag_or_env
    arg_processor = MirahArguments.new({})
    arg_processor.apply_args ["-d", "some/path"]

    assert_equal_classpaths "some/path",
                 arg_processor.real_classpath
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

  def assert_equal_classpaths expected, actual_classpath_list
    normalized_expected = Mirah::Env.decode_paths(expected).
      map { |p| "#{File.new(::File.expand_path(p)).toURI.toURL}#{"./" if p == "." }" }
    assert_equal Mirah::Env.encode_paths(normalized_expected),
                 Mirah::Env.encode_paths(actual_classpath_list.map{ |u| u.to_s })
  end
end
