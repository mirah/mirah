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

class VarargsTest < Test::Unit::TestCase

  def test_varargs_method_with_passed_varargs
    cls, = compile(<<-EOF)
      puts String.format("%s %s's", "rocking", "banana")
    EOF
    assert_output "rocking banana's\n" do
      cls.main nil
    end
  end

  def test_varargs_method_lookup_without_passed_varargs
    cls, = compile(<<-EOF)
      puts String.format("rocking with no args")
    EOF
    assert_output "rocking with no args\n" do
      cls.main nil
    end
  end

  def test_varargs_method_lookup_when_passed_array
    cls, = compile(<<-EOF)
      args = String[1]
      args[0] = "an array"
      puts String.format("rocking with %s", args)
    EOF
    assert_output "rocking with an array\n" do
      cls.main nil
    end
  end

end
