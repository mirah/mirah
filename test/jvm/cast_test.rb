# Copyright (c) 2013 The Mirah project authors. All Rights Reserved.
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

class CastTest < Test::Unit::TestCase

  def test_cast
    cls, = compile(<<-EOF)
      def f2b; 1.0.as!(byte); end
      def f2s; 1.0.as!(short); end
      def f2c; 1.0.as!(char); end
      def f2i; 1.0.as!(int); end
      def f2l; 1.0.as!(long); end
      def f2d; 1.0.as!(int); end

      def i2b; 1.as!(byte); end
      def i2s; 1.as!(short); end
      def i2c; 1.as!(char); end
      def i2l; 1.as!(long); end
      def i2f; 1.as!(float); end
      def i2d; 1.as!(int); end

      def b2s; 1.as!(byte).as!(short); end
      def b2c; 1.as!(byte).as!(char); end
      def b2i; 1.as!(byte).as!(int); end
      def b2l; 1.as!(byte).as!(long); end
      def b2f; 1.as!(byte).as!(float); end
      def b2d; 1.as!(byte).as!(double); end

      def s2b; 1.as!(short).as!(byte); end
      def s2c; 1.as!(short).as!(char); end
      def s2i; 1.as!(short).as!(int); end
      def s2l; 1.as!(short).as!(long); end
      def s2f; 1.as!(short).as!(float); end
      def s2d; 1.as!(short).as!(double); end

      def c2b; 1.as!(char).as!(byte); end
      def c2s; 1.as!(char).as!(short); end
      def c2i; 1.as!(char).as!(int); end
      def c2l; 1.as!(char).as!(long); end
      def c2f; 1.as!(char).as!(float); end
      def c2d; 1.as!(char).as!(double); end

      def l2b; 1.as!(long).as!(byte); end
      def l2c; 1.as!(long).as!(char); end
      def l2i; 1.as!(long).as!(int); end
      def l2l; 1.as!(long).as!(long); end
      def l2f; 1.as!(long).as!(float); end
      def l2d; 1.as!(long).as!(double); end

      def d2b; 1.0.as!(byte); end
      def d2s; 1.0.as!(short); end
      def d2c; 1.0.as!(char); end
      def d2i; 1.0.as!(int); end
      def d2l; 1.0.as!(long); end
      def d2f; 1.0.as!(float); end

      def hard_i2f(a:int)
        if a < 0
          a *= -1
          a * 2
        else
          a * 2
        end.as! float
      end
    EOF

    assert_equal 1, cls.b2s
    assert_equal 1, cls.b2c
    assert_equal 1, cls.b2i
    assert_equal 1, cls.b2l
    assert_equal 1.0, cls.b2f
    assert_equal 1.0, cls.b2d

    assert_equal 1, cls.s2b
    assert_equal 1, cls.s2c
    assert_equal 1, cls.s2i
    assert_equal 1, cls.s2l
    assert_equal 1.0, cls.s2f
    assert_equal 1.0, cls.s2d

    assert_equal 1, cls.c2b
    assert_equal 1, cls.c2s
    assert_equal 1, cls.c2i
    assert_equal 1, cls.c2l
    assert_equal 1.0, cls.c2f
    assert_equal 1.0, cls.c2d

    assert_equal 1, cls.i2b
    assert_equal 1, cls.i2s
    assert_equal 1, cls.i2c
    assert_equal 1, cls.i2l
    assert_equal 1.0, cls.i2f
    assert_equal 1.0, cls.i2d

    assert_equal 1, cls.f2b
    assert_equal 1, cls.f2s
    assert_equal 1, cls.f2c
    assert_equal 1, cls.f2i
    assert_equal 1, cls.f2l
    assert_equal 1.0, cls.f2d

    assert_equal 1, cls.d2b
    assert_equal 1, cls.d2s
    assert_equal 1, cls.d2c
    assert_equal 1, cls.d2i
    assert_equal 1, cls.d2l
    assert_equal 1.0, cls.d2f

    assert_equal 2.0, cls.hard_i2f(1)
    assert_equal 4.0, cls.hard_i2f(-2)
  end

  def test_java_lang_cast
    cls, = compile(<<-EOF)
      def foo(a:Object)
        Integer(a).intValue
      end
    EOF

    assert_equal(2, cls.foo(java.lang.Integer.new(2)))
  end

  def test_array_cast
    cls, = compile(<<-EOF)
      def foo(a: Object)
        bar(a.as!(String[]))
      end

      def bar(a: String[])
        a[0]
      end
    EOF

    assert_equal("foo", cls.foo(["foo", "bar"].to_java(:string)))
  end


  def test_warn_on_array_cast
    # TODO
    cls, = compile(<<-EOF)
      def foo(a:Object)
        bar(String[].cast(a))
      end

      def bar(a:String[])
        a[0]
      end
    EOF

    assert_equal("foo", cls.foo(["foo", "bar"].to_java(:string)))
  end

  def test_cast_array_as_primitive
    cls, = compile(<<-EOF)
      def foo(a:Object)
        bar(a.as!(int[]))
      end

      def bar(a:int[])
        a[0]
      end
    EOF

    assert_equal(2, cls.foo([2, 3].to_java(:int)))
  end

  def test_array_cast_primitive
    cls, = compile(<<-EOF)
      def foo(a:Object)
        bar(int[].cast(a))
      end

      def bar(a:int[])
        a[0]
      end
    EOF

    assert_equal(2, cls.foo([2, 3].to_java(:int)))
  end
  
  def test_explicit_block_argument_cast_in_array_iteration
     cls, = compile(<<-EOF)
      def foo():int
        list = [1,2,3]
        m = 0
        list.each do |x: int|
          m += x
        end
        return m
      end
    EOF
    assert_equal 6, cls.foo
  end
  
  def test_explicit_call_cast_in_array_iteration
     cls, = compile(<<-EOF)
      def foo():int
        list = [1,2,3]
        m = 0
        list.each do |x|
          m = int(x) + m
        end
        return m
      end
    EOF
    assert_equal 6, cls.foo
  end

  def test_explicit_as_macro_cast_in_array_iteration
     cls, = compile(<<-EOF)
      def foo():int
        list = [1,2,3]
        m = 0
        list.each do |x|
          m = x.as!(int) + m
        end
        return m
      end
    EOF
    assert_equal 6, cls.foo
  end
end
