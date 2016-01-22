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

class ObjectExtensionsTest < Test::Unit::TestCase

  def test_tap
    cls, = compile(%q[
      def taptest
        StringBuilder.new("abc").tap do |sb|
          sb.append("xyz")
          StringBuilder.new("ijk")
        end
      end
    ])
    assert_equal("abcxyz", cls.taptest.toString)
  end
  
  def test_equals_each_side_is_evaluated_exactly_once
    cls, = compile(%q[
      def foo
        puts "foo"
        "1"
      end
      
      def bar
        puts "bar"
        "2"
      end

      puts foo==bar
      puts nil==bar # right side is always evaluated exactly once, even in the presence of nil on the other side
      puts bar==nil # left  side is always evaluated exactly once, even in the presence of nil on the other side
    ])
    assert_run_output("foo\nbar\nfalse\nbar\nfalse\nbar\nfalse\n", cls)
  end
  
  def test_equals_method_is_evaluated_as_necessary
    cls, = compile(%q[
      class Foo
        attr_accessor counter:int
        def equals(o:Object)
          self.counter += 1
          true
        end
      end
      
      class Bar < Foo
      end
      
      class Baz < Foo
      end
      
      bar = Bar.new
      baz = Baz.new
      puts bar==baz
      puts bar.counter
      puts baz.counter
      puts nil==bar
      puts bar.counter
      puts bar==nil
      puts bar.counter
      puts bar==bar
      puts bar.counter
    ])
    assert_run_output("true\n1\n0\nfalse\n1\ntrue\n2\ntrue\n3\n", cls)
  end
  
  def test_equals_method_is_evaluated_exactly_once_even_on_identical_objects
    cls, = compile(%q[
      class NaN
        def equals(o:Object)
          false
        end
      end
      
      nan = NaN.new
      puts nan==nan
    ])
    assert_run_output("false\n", cls)
  end
  
  def test_re_defined_method_does_not_fire_on_actual_override
    cls, = compile(%q'
      class AnySuper
        def foo(a:int, b:java::util::List = nil)
          "abc"
        end
      end
      
      class TestReMacro < AnySuper
        re def foo(a:int)
          "xy#{a}z"
        end
        
        re def foo(a:int, b:java::util::List)
          "xy#{a}z#{b.size}"
        end
        
        re def hashCode:int
          7
        end
        
        re def equals(o:Object):boolean
          false
        end
      end
      
      a = TestReMacro.new
      puts a.foo(4)
      puts a.foo(5, [])
      puts a.hashCode
      puts a.equals(a)
    ')
    assert_run_output("xy4z\nxy5z0\n7\nfalse\n", cls)
  end
  
  def test_re_defined_method_does_fire_on_missing_override
    assert_raise_java(Mirah::MirahError, /requires to override a method, but no matching method is actually overridden/) do
      cls, = compile(%q'
        class AnySuper
          def foo(a:int, b:java::util::List = nil)
            "abc"
          end
        end
        
        class TestReMacro < AnySuper
          re def foo(a:int, b:java::util::ArrayList)
            "xy#{a}z#{b.size}"
          end
        end
        
        a = TestReMacro.new
        puts a.foo(5, [])
      ')
    end
  end
end
