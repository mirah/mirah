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

class CastTest < Test::Unit::TestCase

  def test_cast
    cls, = compile(<<-EOF)
      def f2b; byte(1.0); end
      def f2s; short(1.0); end
      def f2c; char(1.0); end
      def f2i; int(1.0); end
      def f2l; long(1.0); end
      def f2d; int(1.0); end

      def i2b; byte(1); end
      def i2s; short(1); end
      def i2c; char(1); end
      def i2l; long(1); end
      def i2f; float(1); end
      def i2d; int(1); end

      def b2s; short(byte(1)); end
      def b2c; char(byte(1)); end
      def b2i; int(byte(1)); end
      def b2l; long(byte(1)); end
      def b2f; float(byte(1)); end
      def b2d; double(byte(1)); end

      def s2b; byte(short(1)); end
      def s2c; char(short(1)); end
      def s2i; int(short(1)); end
      def s2l; long(short(1)); end
      def s2f; float(short(1)); end
      def s2d; double(short(1)); end

      def c2b; byte(char(1)); end
      def c2s; short(char(1)); end
      def c2i; int(char(1)); end
      def c2l; long(char(1)); end
      def c2f; float(char(1)); end
      def c2d; double(char(1)); end

      def l2b; byte(long(1)); end
      def l2c; char(long(1)); end
      def l2i; int(long(1)); end
      def l2l; long(long(1)); end
      def l2f; float(long(1)); end
      def l2d; double(long(1)); end

      def d2b; byte(1.0); end
      def d2s; short(1.0); end
      def d2c; char(1.0); end
      def d2i; int(1.0); end
      def d2l; long(1.0); end
      def d2f; float(1.0); end

      def hard_i2f(a:int)
        float(if a < 0
          a *= -1
          a * 2
        else
          a * 2
        end)
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
      def foo(a:Object)
        bar(String[].cast(a))
      end

      def bar(a:String[])
        a[0]
      end
    EOF

    assert_equal("foo", cls.foo(["foo", "bar"].to_java(:string)))
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
end
