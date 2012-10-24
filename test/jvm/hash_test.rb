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

class HashTest < Test::Unit::TestCase
  def test_hashes
    cls, = compile(<<-EOF)
      def foo1
        {a:"A", b:"B"}
      end
      def foo2
        return {a:"A", b:"B"}
      end
    EOF

    map = cls.foo1
    assert_equal("A", map["a"])
    assert_equal("B", map["b"])
    map = cls.foo2
    assert_equal("A", map["a"])
    assert_equal("B", map["b"])

    cls, = compile(<<-'EOF')
      def set(b:Object)
        map = { }
        map["key"] = b
        map["key"]
      end
    EOF

    assert_equal("foo", cls.set("foo"))
  end

  def test_hash_with_value_from_static_method
    cls, = compile(<<-EOF)
      def foo1
        {a: a, b:"B"}
      end
      def a
        return "A"
      end
    EOF
    assert_equal("A", cls.foo1["a"])
  end

  def test_hash_with_value_from_instance_method
    cls, = compile(<<-EOF)
      class HashTesty
        def foo1
          {a: a, b:"B"}
        end
        def a
          return "A"
        end
      end
    EOF
    assert_equal("A", cls.new.foo1["a"])
  end

  def test_scoped_self_through_method_call
    cls, = compile(<<-EOF)
      class ScopedSelfThroughMethodCall
        def emptyMap
          {}
        end

        def foo
          emptyMap["a"] = "A"
        end
      end
    EOF

    # just make sure it can execute
    m = cls.new.foo
  end

  def test_self_call_preserves_scope
    cls, = compile(<<-EOF)
      class SelfCallPreservesScope
        def key
          "key"
        end

        def foo
          map = {}
          map[key] = "value"
          map
        end
      end
    EOF

    map = cls.new.foo
    assert_equal("value", map["key"])
  end
end
