# Copyright (c) 2014 The Mirah project authors. All Rights Reserved.
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



class JvmVersionTest < Test::Unit::TestCase
  java_import 'org.mirah.jvm.compiler.JvmVersion'
  java_import 'org.objectweb.asm.Opcodes'

  def test_defaults_to_current_java
    jvm_version = JvmVersion.new
    spec_version = ENV_JAVA['java.specification.version']
    assert_equal spec_version, jvm_version.version_string
    assert_equal opcode(spec_version), jvm_version.bytecode_version
  end
  
  supported_versions = %w[1.4 1.5 1.6 1.7 1.8]
  supported_versions.each do |version|
    define_method  "test_setting_version_to_#{version.tr '.', '_'}" do
			jvm_version = JvmVersion.new version
			assert_equal version, jvm_version.version_string
			assert_equal opcode(version), jvm_version.bytecode_version
		end
  end

  def test_java_8_supports_default_methods
    jvm_version = JvmVersion.new "1.8"
    assert jvm_version.supports_default_interface_methods
  end

  def test_java_7_does_not_support_default_methods
    jvm_version = JvmVersion.new "1.7"
    assert !jvm_version.supports_default_interface_methods
  end

  def opcode spec_version
    Opcodes.const_get("V#{spec_version.sub('.','_')}")
  end
end