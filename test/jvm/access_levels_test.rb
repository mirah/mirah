# Copyright (c) 2015 The Mirah project authors. All Rights Reserved.
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

class AccessLevelsTest < Test::Unit::TestCase
  def test_private_method_inaccessible_externally
    cls, = compile("private def foo; a = 1; a; end; def bar; foo; end")

    assert_raise NoMethodError  do
      cls.foo
    end
  end

  def test_private_method_accessible_internally
    cls, = compile("private def foo; a = 1; a; end; def bar; foo; end")

    assert_equal 1, cls.bar
  end
end