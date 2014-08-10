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


class JVMCommandsTest < Test::Unit::TestCase

  def test_dash_e_eval
    assert_output "1\n" do
      Mirah.run('-e','puts 1')
    end
  end

  def test_force_verbose_has_logging
    out = capture_output do
      Mirah.run('-V', '-e','puts 1')
    end
    assert out.include? "Finished class DashE"
  end

  def test_runtime_classpath_modifications
    assert_output "1234\n" do
      Mirah.run('-cp', FIXTURE_TEST_DEST,
                                '-e',
                                  'import org.foo.LowerCaseInnerClass
                                  puts LowerCaseInnerClass.inner.field'
                              )
    end
  end

  def test_dash_c_is_deprecated
    assert_output "WARN: option -c is deprecated.\n1234\n" do
      Mirah.run('-c', FIXTURE_TEST_DEST,
                                '-e',
                                  'import org.foo.LowerCaseInnerClass
                                  puts LowerCaseInnerClass.inner.field'
                              )
    end
  end
end
