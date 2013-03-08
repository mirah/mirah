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

class CampilationStateTest < Test::Unit::TestCase
  include Mirah::Util
  def test_defaults_to_current_java
    state = CompilationState.new
    spec_version = ENV_JAVA['java.specification.version']
    assert_equal spec_version, state.target_jvm_version
    assert_equal bitescript_const(spec_version), state.bytecode_version
  end

  %w[1.4 1.5 1.6 1.7 1.8].each do |version|
    define_method  "test_setting_version_to_#{version.tr '.', '_'}" do
      state = CompilationState.new
      state.set_jvm_version version
      assert_equal version, state.target_jvm_version
      assert_equal bitescript_const(version), state.bytecode_version
    end
  end

  def bitescript_const version
    BiteScript.const_get("JAVA#{version.gsub('.', '_')}")
  end
end
