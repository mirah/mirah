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

class GenericsTest < Test::Unit::TestCase

  def test_generics_calls_collections
    cls, = compile(<<-EOF)
      import java.util.ArrayList

      foo = ArrayList.new()
      foo.add("first string")
      foo.add("second string")
      puts(foo.get(1).substring(2))
    EOF

    assert_run_output("cond string\n", cls)
  end

  def test_generics_generic_payload
    cls, = compile(<<-EOF)
      import java.util.ArrayList

      foo = ArrayList.new()
      foo.add("first string")
      foo.add("second string")
      bar = ArrayList.new()
      bar.add(foo)
      puts(bar.get(0).get(1).substring(2))
    EOF

    assert_run_output("cond string\n", cls)
  end

  def test_generics_recursion
    omit_if JVMCompiler::JVM_VERSION.to_f < 1.8

    # Class signature for java.util.stream.Stream is recursive
    #<T:Ljava/lang/Object;>Ljava/lang/Object;Ljava/util/stream/BaseStream<TT;Ljava/util/stream/Stream<TT;>;>;
    cls, = compile(<<-EOF)
      [10,5,8].stream.sorted.forEach { |i| puts i}
    EOF
    assert_run_output("5\n8\n10\n", cls)
  end


end

