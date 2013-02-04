# Copyright (c) 2012 The Mirah project authors. All Rights Reserved.
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
require 'jvm/bytecode_test_helper'
class TestGenerics < Test::Unit::TestCase

  def parse_and_type code, name=tmp_script_name
    parse_and_resolve_types name, code
  end

  def test_generics_calls_collections
    cls, = compile(<<-EOF)
      import java.util.ArrayList

      foo = ArrayList.new()
      foo.add("first string")
      foo.add("second string")
      System.out.println(foo.get(1).substring(2))
    EOF

    assert_output("cond string\n") do
      cls.main(nil)
    end
  end

  def test_generics_generic_payload
    cls, = compile(<<-EOF)
      import java.util.ArrayList

      foo = ArrayList.new()
      foo.add("first string")
      foo.add("second string")
      bar = ArrayList.new()
      bar.add(foo)
      System.out.println(bar.get(0).get(1).substring(2))
    EOF

    assert_output("cond string\n") do
      cls.main(nil)
    end
  end

end

