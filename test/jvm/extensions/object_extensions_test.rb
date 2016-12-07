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

  def test_boxing_for_equals
    cls, = compile(%q[
      puts true==true
      puts false==true
      puts nil==true

      obj = Boolean true
      puts obj == true
      puts obj == false

      b = true
      puts obj == b
      puts obj == 1
      puts true == obj
    ])
    assert_run_output("true\nfalse\nfalse\ntrue\nfalse\ntrue\nfalse\ntrue\n", cls)
  end

  def test_boxing_for_numerics
    cls, = compile(%q[
      puts 1==Long.new(1)
      puts Long(nil)==Long.new(1)
      puts 1==Long.new(2)
      puts nil == Long.new(2)
    ])
    assert_run_output("true\nfalse\nfalse\nfalse\n", cls)
  end

end
