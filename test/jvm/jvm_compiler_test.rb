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

class JVMCompilerTest < Test::Unit::TestCase

  def assert_raise_java(type, message="")
    ex = assert_raise(type) do
      yield
    end
    assert_equal message, ex.message.to_s
  end

  def test_local
    cls, = compile("def foo; a = 1; a; end")
    assert_equal(1, cls.foo)

    cls, = compile("def foo; a = 1.0; a; end")
    assert_equal(1.0, cls.foo)

    cls, = compile("def foo; a = 'bar'; a; end")
    assert_equal('bar', cls.foo)
  end

  def test_addition
    cls, = compile("def foo; a = 1; b = 2; a + b; end")
    assert_equal(3, cls.foo)

    cls, = compile("def foo; a = 1.0; b = 2.0; a + b; end")
    assert_equal(3.0, cls.foo)
  end

  def test_subtraction
    cls, = compile("def foo; a = 3; b = 2; a - b; end")
    assert_equal(1, cls.foo)

    cls, = compile("def foo; a = 3.0; b = 2.0; a - b; end")
    assert_equal(1.0, cls.foo)
  end

  def test_multiplication
    cls, = compile("def foo; a = 2; b = 3; a * b; end")
    assert_equal(6, cls.foo)

    cls, = compile("def foo; a = 2.0; b = 3.0; a * b; end")
    assert_equal(6.0, cls.foo)
  end

  def test_division
    cls, = compile("def foo; a = 6; b = 3; a / b; end")
    assert_equal(2, cls.foo)

    cls, = compile("def foo; a = 6.0; b = 3.0; a / b; end")
    assert_equal(2.0, cls.foo)
  end

  def test_rem
    cls, = compile("def foo; a = 7; b = 3; a % b; end")
    assert_equal(1, cls.foo)

    cls, = compile("def foo; a = 8.0; b = 3.0; a % b; end")
    assert_equal(2.0, cls.foo)
  end

  def test_shift_left
    cls, = compile("def foo; a = 1; b = 3; a << b; end")
    assert_equal(8, cls.foo)
  end

  def test_shift_right
    cls, = compile("def foo; a = 7; b = 2; a >> b; end")
    assert_equal(1, cls.foo)

    cls, = compile("def foo; a = -1; b = 1; a >> b; end")
    assert_equal(-1, cls.foo)
  end

  # TODO the parser doesn't like >>>

  # def test_unsigned_shift_right
  #   cls, = compile("def foo; a = -1; b = 31; a >>> b; end")
  #   assert_equal(1, cls.foo)
  # end

  def test_binary_and
    cls, = compile("def foo; a = 7; b = 3; a & b; end")
    assert_equal(3, cls.foo)
  end

  def test_binary_or
    cls, = compile("def foo; a = 4; b = 3; a | b; end")
    assert_equal(7, cls.foo)
  end

  def test_binary_xor
    cls, = compile("def foo; a = 5; b = 3; a ^ b; end")
    assert_equal(6, cls.foo)
  end

  def test_return
    cls, = compile("def foo; return 1; end")
    assert_equal(1, cls.foo)

    cls, = compile("def foo; return 1.0; end")
    assert_equal(1.0, cls.foo)

    cls, = compile("def foo; return 'bar'; end")
    assert_equal('bar', cls.foo)
  end

  def test_primitive_array
    cls, = compile("def foo; a = boolean[2]; a; end")
    assert_equal(Java::boolean[].java_class, cls.foo.class.java_class)
    assert_equal([false,false], cls.foo.to_a)
    cls, = compile("def foo; a = boolean[2]; a[0] = true; a[0]; end")
    assert_equal(TrueClass, cls.foo.class)
    assert_equal(true, cls.foo)
    cls, = compile("def foo; a = boolean[2]; a.length; end")
    assert_equal(Fixnum, cls.foo.class)
    assert_equal(2, cls.foo)

    cls, = compile("def foo; a = byte[2]; a; end")
    assert_equal(Java::byte[].java_class, cls.foo.class.java_class)
    assert_equal([0,0], cls.foo.to_a)
    cls, = compile("def foo; a = byte[2]; a[0] = 1; a[0]; end")
    assert_equal(Fixnum, cls.foo.class)
    assert_equal(1, cls.foo)

    cls, = compile("def foo; a = short[2]; a; end")
    assert_equal(Java::short[].java_class, cls.foo.class.java_class)
    assert_equal([0,0], cls.foo.to_a)
    cls, = compile("def foo; a = short[2]; a[0] = 1; a[0]; end")
    assert_equal(Fixnum, cls.foo.class)
    assert_equal(1, cls.foo)

    cls, = compile("def foo; a = char[2]; a; end")
    assert_equal(Java::char[].java_class, cls.foo.class.java_class)
    assert_equal([0,0], cls.foo.to_a)
    # Pending char constants or casts
    # cls, = compile("def foo; a = char[2]; a[0] = 1; a[0]; end")
    # assert_equal(Fixnum, cls.foo.class)
    # assert_equal(1, cls.foo)

    cls, = compile("def foo; a = int[2]; a; end")
    assert_equal(Java::int[].java_class, cls.foo.class.java_class)
    assert_equal([0,0], cls.foo.to_a)
    cls, = compile("def foo; a = int[2]; a[0] = 1; a[0]; end")
    assert_equal(Fixnum, cls.foo.class)
    assert_equal(1, cls.foo)

    cls, = compile("def foo; a = long[2]; a; end")
    assert_equal(Java::long[].java_class, cls.foo.class.java_class)
    assert_equal([0,0], cls.foo.to_a)
    cls, = compile(<<-EOF)
      def foo
        a = long[2]
        a[0] = 1
        a[0]
      end
    EOF
    assert_equal(Fixnum, cls.foo.class)
    assert_equal(1, cls.foo)

    cls, = compile("def foo; a = float[2]; a; end")
    assert_equal(Java::float[].java_class, cls.foo.class.java_class)
    assert_equal([0.0,0.0], cls.foo.to_a)
    cls, = compile("def foo; a = float[2]; a[0] = float(1.0); a[0]; end")
    assert_equal(Float, cls.foo.class)
    assert_equal(1.0, cls.foo)

    cls, = compile("def foo; a = double[2]; a; end")
    assert_equal(Java::double[].java_class, cls.foo.class.java_class)
    assert_equal([0.0,0.0], cls.foo.to_a)
    cls, = compile(<<-EOF)
      def foo
        a = double[2]
        a[0] = 1.0
        a[0]
      end
    EOF
    assert_equal(Float, cls.foo.class)
    assert_equal(1.0, cls.foo)
  end

  def test_array_with_dynamic_size
    cls, = compile("def foo(size:int); a = int[size + 1];end")
    array = cls.foo(3)
    assert_equal(Java::int[].java_class, array.class.java_class)
    assert_equal([0,0,0,0], array.to_a)
  end

  def test_object_array
    cls, = compile("import java.lang.Object;def foo; a = Object[2];end")
    assert_equal(Java::JavaLang::Object[].java_class, cls.foo.class.java_class)
    assert_equal([nil, nil], cls.foo.to_a)
  end

  def test_string_concat
    cls, = compile("
      def str_str; a = 'a'; b = 'b'; a + b; end
      def str_boolean; a = 'a'; b = false; a + b; end
      def str_float; a = 'a'; b = float(1.0); a + b; end
      def str_double; a = 'a'; b = 1.0; a + b; end
      def str_byte; a = 'a'; b = byte(1); a + b; end
      def str_short; a = 'a'; b = short(1); a + b; end
      def str_char; a = 'a'; b = char(123); a + b; end
      def str_int; a = 'a'; b = 1; a + b; end
      def str_long; a = 'a'; b = long(1); a + b; end
    ")
    assert_equal("ab", cls.str_str)
    assert_equal("afalse", cls.str_boolean)
    assert_equal("a1.0", cls.str_float)
    assert_equal("a1.0", cls.str_double)
    assert_equal("a1", cls.str_byte)
    assert_equal("a1", cls.str_short)
    assert_equal("a{", cls.str_char)
    assert_equal("a1", cls.str_int)
    assert_equal("a1", cls.str_long)
  end

  def test_void_selfcall
    cls, = compile("import 'System', 'java.lang.System'; def foo; System.gc; end; foo")
    assert_nothing_raised {cls.foo}
  end

  def test_void_chain
    cls, = compile(<<-EOF)
      import java.io.*
      def foo
        # throws IOException
        OutputStreamWriter.new(
            System.out).write("Hello ").write("there\n").flush
      end
    EOF

    assert_output("Hello there\n") { cls.foo }

    a, b = compile(<<-EOF)
      class VoidBase
        def foo:void
          System.out.println "foo"
        end
      end
      class VoidChain < VoidBase
        def bar:void
          System.out.println "bar"
        end

        def self.foobar
          VoidChain.new.foo.bar
        end
      end
    EOF
    assert_output("foo\nbar\n") { b.foobar }

  end

  def test_import
    cls, = compile("import 'java.util.ArrayList'; def foo; ArrayList.new; end; foo")
    assert_equal java.util.ArrayList.java_class, cls.foo.java_class

    cls, = compile("import 'AL', 'java.util.ArrayList'; def foo; AL.new; end; foo")
    assert_equal java.util.ArrayList.java_class, cls.foo.java_class
  end

  def test_no_quote_import
    cls, = compile("import java.util.ArrayList as AL; def foo; AL.new; end; foo")
    assert_equal java.util.ArrayList.java_class, cls.foo.java_class

    cls, = compile("import java.util.ArrayList; def foo; ArrayList.new; end; foo")
    assert_equal java.util.ArrayList.java_class, cls.foo.java_class
  end

  def test_imported_decl
    cls, = compile("import 'java.util.ArrayList'; def foo(a:ArrayList); a.size; end")
    assert_equal 0, cls.foo(java.util.ArrayList.new)
  end

  def test_import_package
    cls, = compile(<<-EOF)
      import java.util.*
      def foo
        ArrayList.new
      end
    EOF
    assert_equal java.util.ArrayList.java_class, cls.foo.java_class
  end

  def test_interface
    cls, = compile(<<-EOF)
      import 'java.util.concurrent.Callable'
      def foo(a:Callable)
        a.call
      end
    EOF
    result = cls.foo {0}
    assert_equal 0, result
    m = cls.java_class.java_method 'foo', java.util.concurrent.Callable
  end

  def test_class_decl
    foo, = compile("class ClassDeclTest;end")
    assert_equal('ClassDeclTest', foo.java_class.name)
  end

  def test_class_name_from_file_with_underscore
    foo, = compile("System.out.println 'blah'", 'class_name_test.mirah')
    assert_equal('ClassNameTest', foo.java_class.name)
  end

  def test_class_name_from_file_with_dash
    foo, = compile("System.out.println 'blah'", 'class-dash-test.mirah')
    assert_equal('ClassDashTest', foo.java_class.name)
  end

  def test_puts
    cls, = compile("def foo;puts 'Hello World!';end")
    output = capture_output do
      cls.foo
    end
    assert_equal("Hello World!\n", output)
  end

  def test_print
    cls, = compile("def foo;print 'Hello World!';end")
    output = capture_output do
      cls.foo
    end
    assert_equal("Hello World!", output)
  end

  def test_method
    # TODO auto generate a constructor
    cls, = compile(
      "class MethodTest; def foo; 'foo';end;end")
    instance = cls.new
    assert_equal(cls, instance.class)
    assert_equal('foo', instance.foo)
  end

  def test_unless_fixnum
    cls, = compile(<<-EOF)
      def foo(a:fixnum)
        values = boolean[5]
        values[0] = true unless a < 0
        values[1] = true unless a <= 0
        values[2] = true unless a == 0
        values[3] = true unless a >= 0
        values[4] = true unless a > 0
        values
      end
    EOF
    assert_equal [true, true, true, false, false], cls.foo(1).to_a
    assert_equal [true, false, false, false, true], cls.foo(0).to_a
    assert_equal [false, false, true, true, true], cls.foo(-1).to_a
  end

  def test_unless_float
    cls, = compile(<<-EOF)
      def foo(a:float)
        values = boolean[5]
        values[0] = true unless a < 0.0
        values[1] = true unless a <= 0.0
        values[2] = true unless a == 0.0
        values[3] = true unless a >= 0.0
        values[4] = true unless a > 0.0
        values
      end
    EOF
    assert_equal [true, true, true, false, false], cls.foo(1.0).to_a
    assert_equal [true, false, false, false, true], cls.foo(0.0).to_a
    assert_equal [false, false, true, true, true], cls.foo(-1.0).to_a
  end

  def test_if_fixnum
    cls, = compile(<<-EOF)
      def foo(a:fixnum)
        if a < -5
          -6
        elsif a <= 0
          0
        elsif a == 1
          1
        elsif a > 4
          5
        elsif a >= 3
          3
        else
          2
        end
      end
    EOF
    assert_equal(-6, cls.foo(-6))
    assert_equal(0, cls.foo(-5))
    assert_equal(0, cls.foo(0))
    assert_equal(1, cls.foo(1))
    assert_equal(2, cls.foo(2))
    assert_equal(3, cls.foo(3))
    assert_equal(3, cls.foo(4))
    assert_equal(5, cls.foo(5))
  end

  def test_if_float
    cls, = compile(<<-EOF)
      def foo(a:float)
        if a < -5.0
          -6
        elsif a <= 0.0
          0
        elsif a == 1.0
          1
        elsif a > 4.0
          5
        elsif a >= 3.0
          3
        else
          2
        end
      end
    EOF
    assert_equal(-6, cls.foo(-5.1))
    assert_equal(0, cls.foo(-5.0))
    assert_equal(0, cls.foo(0.0))
    assert_equal(1, cls.foo(1.0))
    assert_equal(2, cls.foo(2.5))
    assert_equal(3, cls.foo(3.0))
    assert_equal(3, cls.foo(3.5))
    assert_equal(5, cls.foo(4.1))
  end

  def test_if_boolean
    cls, = compile(<<-EOF)
      def foo(a:boolean)
        if a
          'true'
        else
          'false'
        end
      end
    EOF
    assert_equal('true', cls.foo(true))
    assert_equal('false', cls.foo(false))
  end

  def test_if_int
    # conditions don't work with :int
    # cls, = compile("def foo(a:int); if a < 0; -a; else; a; end; end")
    # assert_equal 1, cls.foo(-1)
    # assert_equal 3, cls.foo(3)
  end

  def test_trailing_conditions
    cls, = compile(<<-EOF)
      def foo(a:fixnum)
        return '+' if a > 0
        return '0' unless a < 0
        '-'
      end
    EOF
    assert_equal '+', cls.foo(3)
    assert_equal '0', cls.foo(0)
    assert_equal '-', cls.foo(-1)
  end

  def test_multi_assign
    cls, = compile(<<-EOF)
      def foo
        array = int[2]
        a = b = 2
        array[0] = a
        array[1] = b
        array
      end
    EOF
    assert_equal([2, 2], cls.foo.to_a)

  end

  def test_loop
    cls, = compile(
        'def foo(a:fixnum);while a > 0; a -= 1; System.out.println ".";end;end')
    assert_equal('', capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})

    cls, = compile(
        'def foo(a:fixnum);begin;a -= 1; System.out.println ".";end while a > 0;end')
    assert_equal(".\n", capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})

    cls, = compile(
        'def foo(a:fixnum);until a <= 0; a -= 1; System.out.println ".";end;end')
    assert_equal('', capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})

    cls, = compile(
        'def foo(a:fixnum);begin;a -= 1; System.out.println ".";end until a <= 0;end')
    assert_equal(".\n", capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})

    cls, = compile(
        'def foo; a = 0; while a < 2; a+=1; end; end')
    assert_equal(nil, cls.foo)

    # TODO: loop doesn't work unless you're explicitly in a class
    # cls, = compile(<<-EOF)
    #   def bar(a:fixnum)
    #     loop do
    #       a += 1
    #       break if a > 2
    #     end
    #     a
    #   end
    # EOF
    # assert_equal(3, cls.bar(0))

    loopy, = compile(<<-EOF)
    class Loopy
      def bar(a:fixnum)
        loop do
          a += 1
          break if a > 2
        end
        a
      end
    end
    EOF

    assert_equal(3, loopy.new.bar(0))
  end

  def test_break
    cls, = compile <<-EOF
      def foo
        count = 0
        while count < 5
          count += 1
          break if count == 1
        end
        count
      end
    EOF
    assert_equal(1, cls.foo)

    cls, = compile <<-EOF
      def foo
        a = 0
        b = 0
        while a < 2
          a += 1
          while b < 5
            b += 1
            break if b > 0
          end
          break if a == 1
        end
        a * 100 + b
      end
    EOF
    assert_equal(101, cls.foo)

    cls, = compile <<-EOF
      def foo
        count = 0
        begin
          count += 1
          break if count == 1
        end while count < 5
        count
      end
    EOF
    assert_equal(1, cls.foo)
  end

  def test_next
    cls, = compile <<-EOF
      def foo
        values = int[3]
        i = 0
        while i < 3
          i += 1
          next if i == 2
          values[i - 1] = i
        end
        values
      end
    EOF
    assert_equal([1, 0, 3], cls.foo.to_a)

    cls, = compile <<-EOF
      def foo
        i = 0
        while i < 5
          i += 1
          next if i == 5
        end
        i
      end
    EOF
    assert_equal(5, cls.foo)

    cls, = compile <<-EOF
      def foo
        values = int[3]
        a = 0
        b = 0
        while a < 3
          b = 0
          while b < 5
            b += 1
            next if b == a + 1
            # values[a] += b # TODO
            values[a] = values[a] + b
          end
          a += 1
          next if a == 2
          values[a - 1] = values[a - 1] + a * 100
        end
        values
      end
    EOF
    assert_equal([114, 13, 312], cls.foo.to_a)

    cls, = compile <<-EOF
      def foo
        count = 0
        sum = 0
        begin
          count += 1
          next if count == 2
          sum += count
          next if count == 5
        end while count < 5
        count * 100 + sum
      end
    EOF
    assert_equal(513, cls.foo)
  end

  def test_redo
    cls, = compile <<-EOF
      def foo
        i = 0
        while i < 5
          i += 1
          redo if i == 5
        end
        i
      end
    EOF
    assert_equal(6, cls.foo)

    cls, = compile <<-EOF
      def foo
        values = int[4]
        a = 0
        b = 0
        while a < 3
          b = a
          while b < 5
            b += 1
            redo if b == 5
            values[a] = values[a] + b
          end
          a += 1
          values[a - 1] = values[a - 1] + a * 100
          redo if a == 3
        end
        values
      end
    EOF
    assert_equal([116, 215, 313, 410], cls.foo.to_a)

    cls, = compile <<-EOF
      def foo
        i = 0
        begin
          i += 1
          redo if i == 5
        end while i < 5
        i
      end
    EOF
    assert_equal(6, cls.foo)
  end

  def test_fields
    cls, = compile(<<-EOF)
      class FieldTest
        def initialize(a:fixnum)
          @a = a
        end

        def a
          @a
        end

        def self.set_b(b:fixnum)
          @@b = b
        end

        def b
          @@b
        end
      end
    EOF
    first = cls.new(1)
    assert_equal(1, first.a)

    second = cls.new(2)
    assert_equal(1, first.a)
    assert_equal(2, second.a)

    cls.set_b 0
    assert_equal(0, first.b)
    assert_equal(0, second.b)
    assert_equal(1, cls.set_b(1))
    assert_equal(1, first.b)
    assert_equal(1, second.b)
  end

  def test_object_intrinsics
    cls, = compile(<<-EOF)
      import 'java.lang.Object'
      def nil(a:Object)
        a.nil?
      end

      def equal(a:Object, b:Object)
        a == b
      end
    EOF

    assert(cls.nil(nil))
    assert(!cls.nil("abc"))

    a = "foobar".to_java_string
    b = java.lang.Object.new
    assert(cls.equal(a, a))
    assert(cls.equal(b, b))
    assert(!cls.equal(a, b))
  end

  def test_implements
    cls, = compile(<<-EOF)
      class ImplementsTest implements Iterable
        def iterator
          nil
        end
      end
    EOF
    assert_include java.lang.Iterable.java_class, cls.java_class.interfaces
  end

  def test_argument_widening
    cls, = compile(<<-EOF)
      def _Byte(a:byte)
        _Short(a)
      end

      def _Short(a:short)
        _Int(a)
      end

      def _Int(a:int)
        _Long(a)
      end

      def _Long(a:long)
        _Float(a)
      end

      def _Float(a:float)
        _Double(a)
      end

      def _Double(a:double)
        a
      end
      EOF

      assert_equal(1.0, cls._Byte(1))
      assert_equal(127.0, cls._Byte(127))
      assert_equal(128.0, cls._Short(128))
      assert_equal(32767.0, cls._Short(32767))
      assert_equal(32768.0, cls._Int(32768))
      assert_equal(2147483648.0, cls._Long(2147483648))
  end

  def test_interface_declaration
    interface = compile('interface A; end').first
    assert(interface.java_class.interface?)
    assert_equal('A', interface.java_class.name)

    a, b = compile('interface A; end; interface B < A; end')
    assert_include(a, b.ancestors)
    assert_equal('A', a.java_class.name)
    assert_equal('B', b.java_class.name)

    a, b, c = compile(<<-EOF)
      interface A
      end

      interface B
      end

      interface C < A, B
      end
    EOF

    assert_include(a, c.ancestors)
    assert_include(b, c.ancestors)
    assert_equal('A', a.java_class.name)
    assert_equal('B', b.java_class.name)
    assert_equal('C', c.java_class.name)
  end

  def test_interface_override_return_type
    assert_raise Mirah::MirahError do
      compile(<<-EOF)
        interface A
          def a:int; end
        end

        class Impl implements A
          def a
            "foo"
          end
        end
      EOF
    end
  end

  def test_raise
    cls, = compile(<<-EOF)
      def foo
        raise
      end
    EOF
    assert_raise_java(java.lang.Exception) do
      cls.foo
    end

    cls, = compile(<<-EOF)
      def foo
        raise "Oh no!"
      end
    EOF
    ex = assert_raise_java(java.lang.Exception, 'Oh no!') do
      cls.foo
    end

    cls, = compile(<<-EOF)
      def foo
        raise IllegalArgumentException
      end
    EOF
    ex = assert_raise_java(java.lang.IllegalArgumentException) do
      cls.foo
    end

    cls, = compile(<<-EOF)
      def foo
        # throws Exception
        raise Exception, "oops"
      end
    EOF
    ex = assert_raise_java(java.lang.Exception, "oops") do
      cls.foo
    end

    cls, = compile(<<-EOF)
      def foo
        # throws Throwable
        raise Throwable.new("darn")
      end
    EOF

    assert_raise_java(java.lang.Throwable, "darn") do
      cls.foo
    end
  end

  def test_ensure
    cls, = compile(<<-EOF)
      def foo
        1
      ensure
        System.out.println "Hi"
      end
    EOF
    output = capture_output do
      assert_equal(1, cls.foo)
    end
    assert_equal "Hi\n", output

    cls, = compile(<<-EOF)
      def foo
        return 1
      ensure
        System.out.println "Hi"
      end
    EOF
    output = capture_output do
      assert_equal(1, cls.foo)
    end
    assert_equal "Hi\n", output

    cls, = compile(<<-EOF)
      def foo
        begin
          break
        ensure
          System.out.println "Hi"
        end while false
      end
    EOF
    output = capture_output do
      cls.foo
    end
    assert_equal "Hi\n", output
  end

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

  def test_set
    cls, = compile(<<-EOF)
      def foo
        @foo
      end

      def foo=(foo:int)
        @foo = foo
      end
    EOF

    assert_equal(0, cls.foo)
    assert_equal(2, cls.foo_set(2))
    assert_equal(2, cls.foo)
  end

  def test_null_is_false
    cls, = compile("def foo(a:String);if a;true;else;false;end;end")
    assert_equal(true, cls.foo("a"))
    assert_equal(false, cls.foo(nil))
  end

  def test_if_expr
    cls, = compile(<<-EOF)
      def foo(a:int)
        return 1 if a == 1
      end

      def bar(a:int)
        return 1 unless a == 1
      end
    EOF

    assert_equal(0, cls.foo(0))
    assert_equal(1, cls.foo(1))
    assert_equal(1, cls.bar(0))
    assert_equal(0, cls.bar(1))
  end

  def test_and
    cls, = compile(<<-EOF)
      def bool(n:String, x:boolean)
        System.out.println n
        x
      end

      def foo(a:boolean, b:boolean)
        return bool('a', a) && bool('b', b)
      end

      def str(n:String, x:String)
        System.out.println n
        x
      end

      def bar(a:String, b:String)
        return str('a', a) && str('b', b)
      end
    EOF

    assert_output("a\n") { assert_equal(false, cls.foo(false, true)) }
    assert_output("a\nb\n") { assert_equal(false, cls.foo(true, false)) }
    assert_output("a\nb\n") { assert_equal(true, cls.foo(true, true)) }

    assert_output("a\n") { assert_equal(nil, cls.bar(nil, "B")) }
    assert_output("a\nb\n") { assert_equal(nil, cls.bar("A", nil)) }
    assert_output("a\nb\n") { assert_equal("B", cls.bar("A", "B")) }

    cls, = compile(<<-EOF)
      def s
        @s
      end

      def s=(s:String)
        @s = s
      end

      def b
        @b
      end

      def b=(b:boolean)
        @b = b
      end

      def foo(x:boolean)
        @b &&= x
      end

      def bar(x:String)
        @s &&= x
      end
    EOF

    cls.b_set(false)
    assert_equal(false, cls.foo(false))
    assert_equal(false, cls.b)

    cls.b_set(true)
    assert_equal(false, cls.foo(false))
    assert_equal(false, cls.b)

    cls.b_set(true)
    assert_equal(true, cls.foo(true))
    assert_equal(true, cls.b)

    cls.s_set(nil)
    assert_equal(nil, cls.bar(nil))
    assert_equal(nil, cls.s)

    cls.s_set("S")
    assert_equal(nil, cls.bar(nil))
    assert_equal(nil, cls.s)

    cls.s_set("S")
    assert_equal("x", cls.bar("x"))
    assert_equal("x", cls.s)

    foo, = compile(<<-EOF)
      class Foo2
        def initialize
          @count = 0
        end

        def count
          @count
        end

        def a
          @a
        end

        def a=(a:String)
          @count += 1
          @a = a
        end

        def foo(f:Foo2, x:String)
          f.a &&= x
        end
      end
    EOF

    f = foo.new
    assert_equal(nil, f.foo(f, 'x'))
    assert_equal(0, f.count)

    f = foo.new
    f.a_set("A")
    assert_equal(nil, f.foo(f, nil))
    assert_equal(2, f.count)

    f = foo.new
    f.a_set("A")
    assert_equal('x', f.foo(f, 'x'))
    assert_equal(2, f.count)
  end

  def test_or
    cls, = compile(<<-EOF)
      def bool(n:String, x:boolean)
        System.out.println n
        x
      end

      def foo(a:boolean, b:boolean)
        return bool('a', a) || bool('b', b)
      end

      def str(n:String, x:String)
        System.out.println n
        x
      end

      def bar(a:String, b:String)
        return str('a', a) || str('b', b)
      end
    EOF

    assert_output("a\n") { assert_equal(true, cls.foo(true, false)) }
    assert_output("a\nb\n") { assert_equal(false, cls.foo(false, false)) }
    assert_output("a\nb\n") { assert_equal(true, cls.foo(false, true)) }

    assert_output("a\n") { assert_equal("A", cls.bar("A", nil)) }
    assert_output("a\nb\n") { assert_equal(nil, cls.bar(nil, nil)) }
    assert_output("a\nb\n") { assert_equal("B", cls.bar(nil, "B")) }

    cls, = compile(<<-EOF)
      def s
        @s
      end

      def s=(s:String)
        @s = s
      end

      def b
        @b
      end

      def b=(b:boolean)
        @b = b
      end

      def foo(x:boolean)
        @b ||= x
      end

      def bar(x:String)
        @s ||= x
      end
    EOF

    cls.b_set(false)
    assert_equal(false, cls.foo(false))
    assert_equal(false, cls.b)

    cls.b_set(false)
    assert_equal(true, cls.foo(true))
    assert_equal(true, cls.b)

    cls.b_set(true)
    assert_equal(true, cls.foo(false))
    assert_equal(true, cls.b)

    cls.s_set(nil)
    assert_equal(nil, cls.bar(nil))
    assert_equal(nil, cls.s)

    cls.s_set(nil)
    assert_equal("x", cls.bar("x"))
    assert_equal("x", cls.s)

    cls.s_set("S")
    assert_equal("S", cls.bar("x"))
    assert_equal("S", cls.s)

    foo, = compile(<<-EOF)
      class Foo3
        def initialize
          @count = 0
        end

        def count
          @count
        end

        def a
          @a
        end

        def a=(a:String)
          @count += 1
          @a = a
        end

        def foo(f:Foo3, x:String)
          f.a ||= x
        end
      end
    EOF

    f = foo.new
    assert_equal('x', f.foo(f, 'x'))
    assert_equal(1, f.count)

    f = foo.new
    assert_equal(nil, f.foo(f, nil))
    assert_equal(1, f.count)

    f = foo.new
    f.a_set("A")
    assert_equal("A", f.foo(f, nil))
    assert_equal(1, f.count)

    f = foo.new
    f.a_set("A")
    assert_equal("A", f.foo(f, 'X'))
    assert_equal(1, f.count)
  end

  def test_op_elem_assign
    foo, = compile(<<-EOF)
      class Foo4
        def initialize
          @i = -1
        end

        def i
          @i += 1
        end

        def a
          @a
        end

        def a=(a:String[])
          @a = a
        end

        def foo(x:String)
          a[i] ||= x
        end

        def bar(x:String)
          a[i] &&= x
        end
      end
    EOF

    f = foo.new
    f.a_set([nil, nil, nil].to_java(:string))
    assert_equal(nil, f.bar("x"))
    assert_equal([nil, nil, nil], f.a.to_a)
    assert_equal("x", f.foo("x"))
    assert_equal([nil, "x", nil], f.a.to_a)
  end

  def test_literal_array
    cls, = compile(<<-EOF)
      def foo; System.out.println "hello"; nil; end
      def expr
        [foo]
      end
      def nonexpr
        [foo]
        nil
      end
    EOF

    assert_output("hello\nhello\n") do
      val = cls.expr
      assert val

      val = cls.nonexpr
      assert !val
    end
  end

  def test_literal_regexp
    cls, = compile(<<-EOF)
      def expr
        /foo/
      end
      def matches
        expr.matcher('barfoobaz').find
      end
    EOF

    val = cls.expr
    assert_equal java.util.regex.Pattern, val.class
    assert_equal 'foo', val.to_s

    assert cls.matches
  end

  def test_array_return_type
    cls, = compile(<<-EOF)
      def split
        /foo/.split('barfoobaz')
      end
      def puts
        System.out.println split
      end
    EOF

    assert_nothing_raised do
      result = capture_output {cls.puts}
      assert result =~ /\[Ljava\.lang\.String;@[a-f0-9]+/
    end
    assert_equal java.lang.String.java_class.array_class, cls.split.class.java_class
  end

  def test_same_field_name
    cls, = compile(<<-EOF)
      class A1
        def foo(bar:String)
          @bar = bar
        end
      end

      class B1
        def foo(bar:String)
          @bar = bar
        end
      end

      System.out.println A1.new.foo("Hi")
      System.out.println B1.new.foo("There")
    EOF

    assert_output("Hi\nThere\n") do
      cls.main(nil)
    end
  end

  def test_super
    cls, = compile(<<-EOF)
      class Foo
        def equals(other:Object); super(other); end
      end
    EOF

    obj = cls.new
    assert obj.equals(obj)
    assert !obj.equals(cls.new)
  end

  def test_method_lookup_with_overrides
    cls, = compile(<<-EOF)
      class Bar implements Runnable
        def foo(x:Bar)
          Thread.new(x)
        end
        def run
        end
      end
    EOF

    # Just make sure this compiles.
    # It shouldn't get confused by the Thread(String) constructor.
  end

  def test_optional_args
    cls, = compile(<<-EOF)
      def foo(a:int, b:int = 1, c:int = 2)
        System.out.println a; System.out.println b; System.out.println c
      end
      foo(0)
      foo(0,0)
      foo(0,0,0)
    EOF
    assert_output("0\n1\n2\n0\n0\n2\n0\n0\n0\n") do
      cls.main([].to_java :string)
    end
  end

  def test_field_read
    cls, = compile(<<-EOF)
      System.out.println System.out.getClass.getName
    EOF
    assert_output("java.io.PrintStream\n") do
      cls.main([].to_java :String)
    end
  end

  def test_array_arguments
    cls, = compile(<<-EOF)
      class ArrayArg
        def initialize(foo:byte[]); end

        def self.make_one(foo:byte[])
          ArrayArg.new(foo)
        end
      end
    EOF
    cls.make_one(nil)
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

  def test_string_interpolation
    cls, = compile(<<-EOF)
      def foo(name:String)
        System.out.print "Hello \#{name}."
      end
    EOF

    assert_output("Hello Fred.") do
      cls.foo "Fred"
    end

    cls, = compile(<<-EOF)
      def foo(x:int)
        System.out.print "\#{x += 1}"
        x
      end
    EOF

    assert_output("2") do
      assert_equal(2, cls.foo(1))
    end

    cls, = compile(<<-EOF)
      def foo(a:int)
        "\#{a += 1}"
        a
      end
    EOF
    assert_equal(2, cls.foo(1))
  end

  def test_string_interpolation_method_calls
    cls, = compile <<-CODE
      print "apples \#{'oranges'}".replace('apples', 'oranges')
    CODE
    assert_output "oranges oranges" do
      cls.main nil
    end
  end

  def test_self_dot_static_methods
    cls, = compile(<<-EOF)
      class ClassWithStatics
        def self.a
          b
        end
        def self.b
          print "b"
        end
      end
    EOF

    assert_output("b") do
      cls.a
    end
  end

  def test_evaluation_order
    cls, = compile(<<-EOF)
      def call(a:int, b:int, c:int)
        System.out.print "\#{a}, \#{b}, \#{c}"
      end

      def test_call(a:int)
        call(a, if a < 10;a+=1;a;else;a;end, a)
      end

      def test_string(a:int)
        "\#{a}, \#{if a < 10;a += 1;a;else;a;end}, \#{a}"
      end
    EOF

    assert_output("1, 2, 2") do
      cls.test_call(1)
    end

    assert_equal("2, 3, 3", cls.test_string(2))
  end

  def test_inner_class
    cls, = compile(<<-EOF)
      def foo
        Character::UnicodeBlock.ARROWS
      end
    EOF

    subset = cls.foo
    assert_equal("java.lang.Character$UnicodeBlock", subset.java_class.name)
  end

  def test_class_literal
    cls, = compile(<<-EOF)
      def foo
        String.class.getName
      end
    EOF

    assert_equal("java.lang.String", cls.foo)
  end

  def test_instanceof
    cls, = compile(<<-EOF)
      def string(x:Object)
        x.kind_of?(String)
      end
    EOF

    assert_equal(true, cls.string("foo"))
    assert_equal(false, cls.string(2))
  end

  def test_static_import
    cls, = compile(<<-EOF)
      import java.util.Arrays
      include Arrays
      def list(x:Object[])
        asList(x)
      end
    EOF

    o = ["1", "2", "3"].to_java(:object)
    list = cls.list(o)
    assert_kind_of(Java::JavaUtil::List, list)
    assert_equal(["1", "2", "3"], list.to_a)

    cls, = compile(<<-EOF)
      import java.util.Arrays
      class StaticImports
        include Arrays
        def list(x:Object[])
          asList(x)
        end
      end
    EOF

    list = cls.new.list(o)
    assert_kind_of(Java::JavaUtil::List, list)
    assert_equal(["1", "2", "3"], list.to_a)
  end

  # TODO: need a writable field somewhere...
#  def test_field_write
#    cls, = compile(<<-EOF)
#      old_pi = Math.PI
#      Math.PI = 3.0
#      puts Math.PI
#      Math.PI = old_pi
#      puts Math.PI
#    EOF
#    raise
#    cls.main([].to_java :string)
#    assert_output("3.0\n") do
#      cls.main([].to_java :string)
#    end
#  end

  def test_class_append_self
    cls, = compile(<<-EOF)
      class Append
        class << self
          def hi
            System.out.print 'Static Hello'
          end
        end
      end
    EOF

    output = capture_output do
      cls.hi
    end

    assert_equal('Static Hello', output)
  end

  def test_loop_in_ensure
    cls, = compile(<<-EOF)
    begin
      System.out.println "a"
      begin
        System.out.println "b"
        break
      end while false
      System.out.println "c"
    ensure
      System.out.println "ensure"
    end
    EOF

    assert_output("a\nb\nc\nensure\n") { cls.main(nil) }
  end

  def test_return_type
    assert_raise Mirah::MirahError do
      compile(<<-EOF)
        class ReturnsA
          def a:int
            :foo
          end
        end
      EOF
    end

    assert_raise Mirah::MirahError do
      compile(<<-EOF)
        class ReturnsB
          def self.a:String
            2
          end
        end
      EOF
    end
  end

  def test_abstract
    abstract_class, concrete_class = compile(<<-EOF)
      abstract class Abstract
        abstract def foo:void; end
        def bar; System.out.println "bar"; end
      end
      class Concrete < Abstract
        def foo; System.out.println :foo; end
      end
    EOF

    assert_output("foo\nbar\n") do
      a = concrete_class.new
      a.foo
      a.bar
    end
    assert_raise_java java.lang.InstantiationException do
      abstract_class.new
    end
  end

  def test_return_void
    script, = compile(<<-EOF)
      def foo:void
        System.out.println :hi
        return
      end
    EOF

    assert_output("hi\n") { script.foo }
  end

  def test_package
    script, cls = compile(<<-EOF)
      package foo

      package foo.bar {
        class PackagedBar
          def self.dosomething
            "bar"
          end
        end
      }

      def dosomething
        "foo"
      end
    EOF

    package = script.java_class.name.split('.')[0]
    assert_equal('foo', package)
    assert_equal('foo', script.dosomething)

    assert_equal('bar', cls.dosomething)
    assert_equal("foo.bar.PackagedBar", cls.java_class.name)
  end

  def test_not
    cls, = compile(<<-EOF)
      def foo(x:boolean)
        !x
      end
      def bar(x:Object)
        !x
      end
    EOF
    assert_equal(true, cls.foo(false))
    assert_equal(false, cls.foo(true))
    assert_equal(true, cls.bar(nil))
    assert_equal(false, cls.bar(""))
  end

  def test_rescue_scope
    cls, = compile(<<-EOF)
      def foo
        a = 1
        b = 2
        begin
          raise "Foo"
        rescue => b
          System.out.println a
          System.out.println b.getMessage
        end
        System.out.println b
      end
    EOF

    assert_output("1\nFoo\n2\n") { cls.foo }
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
    # TODO(ribrdb): What is this test for?
    ex = assert_raise Mirah::MirahError  do
      compile("Interface Implements_Go do; end")
    end
    assert_equal("Cannot find class Implements_Go", ex.message)
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

  def test_field_setter_wit_nil
    cls, = compile(<<-EOF)
      import mirah.lang.ast.*
      a = Arguments.new
      a.block = nil
      print "OK"
    EOF
    
    assert_output("OK") { cls.main(nil) }
  end

end
