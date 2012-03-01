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
if true
  def test_hashes
    raise "Hashes not implemented"
  end
else
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

  def test_wide_nonexpressions
    script, cls1, cls2 = compile(<<-EOF)
      class WideA
        def a
          2.5
        end
      end
      
      class WideB < WideA
        def a
          super
          3.5
        end
      end
      
      def self.b
        1.5
      end
      
      1.5
      WideA.new.a
      WideB.new.a
      b
    EOF

    script.main(nil)
  end

  def test_parameter_used_in_block
    cls, = compile(<<-EOF)
      def foo(x:String):void
        thread = Thread.new do
          System.out.println "Hello \#{x}"
        end
        begin
          thread.run
          thread.join
        rescue
          System.out.println "Uh Oh!"
        end
      end
      
      foo('there')
    EOF
    assert_output("Hello there\n") do
      cls.main(nil)
    end
  end

  def test_colon2
    cls, = compile(<<-EOF)
      def foo
        java.util::HashSet.new
      end
    EOF

    assert_kind_of(java.util.HashSet, cls.foo)
  end

  def test_colon2_cast
    cls, = compile(<<-EOF)
      def foo(x:Object)
        java.util::Map.Entry(x)
      end
    EOF

    entry = java.util.HashMap.new(:a => 1).entrySet.iterator.next
    assert_equal(entry, cls.foo(entry))
  end
  
  def test_covariant_arrays
    cls, = compile(<<-EOF)
      System.out.println java::util::Arrays.toString(String[5])
    EOF
    
    assert_output("[null, null, null, null, null]\n") do
      cls.main(nil)
    end
  end
  
  def test_getClass_on_object_array
    cls, = compile(<<-EOF)
      System.out.println Object[0].getClass.getName
    EOF
    
    assert_output("[Ljava.lang.Object;\n") do
      cls.main(nil)
    end
  end

  def test_nil_assign
    cls, = compile(<<-EOF)
    def foo
      a = nil
      a = 'hello'
      a.length
    end
    EOF

    assert_equal(5, cls.foo)

    cls, = compile(<<-EOF)
      a = nil
      System.out.println a
    EOF

    assert_output("null\n") do
      cls.main(nil)
    end
  end

  def test_long_generation
    cls, = compile(<<-EOF)
      c = 2_000_000_000_000
      System.out.println c
    EOF
  end

  def test_missing_class_with_block_raises_inference_error
    assert_raises Typer::InferenceError do
      compile("Interface Implements_Go do; end")
    end
  end
  
  def test_bool_equality
    cls, = compile("System.out.println true == false")
    assert_output("false\n") do
      cls.main(nil)
    end
  end
  
  def test_bool_inequality
    cls, = compile("System.out.println true != false")
    assert_output("true\n") do
      cls.main(nil)
    end
  end
end
end
