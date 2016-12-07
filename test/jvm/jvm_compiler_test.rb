# Copyright (c) 2010-2013 The Mirah project authors. All Rights Reserved.
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

  def test_unary_negation
    cls, = compile("def foo; a = 1; -a; end")
    assert_equal(-1, cls.foo)

    cls, = compile("def foo; a = 1; 1 + -a; end")
    assert_equal(0, cls.foo)
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

  def test_negate
    cls, = compile("def foo; a = 5; -a; end")
    assert_equal(-5, cls.foo)
    cls, = compile("def foo; a = 7.5; -a; end")
    assert_equal(-7.5, cls.foo)
  end

  def test_nan
    cls, = compile("def foo(a:double); if a < 0 then 1 else 2 end; end")
    assert_equal(1, cls.foo(-1))
    assert_equal(2, cls.foo(0))
    assert_equal(2, cls.foo(java.lang.Double::NaN))

    cls, = compile("def foo(a:double); a > 0 ? 1 : 2; end")
    assert_equal(1, cls.foo(1))
    assert_equal(2, cls.foo(-1))
    assert_equal(2, cls.foo(java.lang.Double::NaN))
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

    cls, = compile("def foo; a = char[2]; a[0] = ?x; a[0]; end")
    assert_equal(?x.ord, cls.foo)

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
    pend_on_jruby("1.7.13") do
      cls, = compile("import java.lang.Object;def foo; a = Object[2];end")
      assert_equal(Java::JavaLang::Object[].java_class, cls.foo.class.java_class)
      assert_equal([nil, nil], cls.foo.to_a)
    end
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
          puts "foo"
        end
      end
      class VoidChain < VoidBase
        def bar:void
          puts "bar"
        end

        def self.foobar
          VoidChain.new.foo.bar
        end
      end
    EOF
    assert_output("foo\nbar\n") { b.foobar }

  end

  def test_class_decl
    foo, = compile("class ClassDeclTest;end")
    assert_equal('ClassDeclTest', foo.java_class.name)
  end

  def test_class_name_from_file_with_underscore
    foo, = compile("puts 'blah'", :name => 'class_name_test.mirah')
    assert_equal('ClassNameTestTopLevel', foo.java_class.name)
  end

  def test_class_name_from_file_with_dash
    foo, = compile("puts 'blah'", :name => 'class-dash-test.mirah')
    assert_equal('ClassDashTestTopLevel', foo.java_class.name)
  end

  def test_class_name_from_file_used_within_source_match
    cls, = compile(%q{

      package array_subclass_test
      
      class Subclass < Superclass2
        def self.run
          ArraySubclassTest.new.baz
        end
      end
      
      class ArraySubclassTest
      
        def baz()
          bar(Subclass[3])
        end
      
        def bar(foo:Superclass2[])
          "Success"
        end
      end
      
      class Superclass2
      end
    }, :name => 'Superclass2.mirah')
    assert_equal('Success', cls.run)
  end

  def test_class_name_from_file_used_within_source_mismatch
    cls, = compile(%q{

      package array_subclass_test
      
      class Subclass < Superclass2
        def self.run
          ArraySubclassTest.new.baz
        end
      end
      
      class ArraySubclassTest
      
        def baz()
          bar(Subclass[3])
        end
      
        def bar(foo:Superclass2[])
          "Success"
        end
      end
      
      class Superclass2
      end
    }, :name => 'Superclass3.mirah')
    assert_equal('Success', cls.run)
  end

  def test_puts
    cls, = compile("def foo;puts 'Hello World!';end")
    output = capture_output do
      cls.foo
    end
    assert_equal("Hello World!\n", output)
  end

  def test_puts_classmethod_no_args
    cls, = compile(%q{
      def foo
        puts
        puts
      end
    })
    output = capture_output do
      cls.foo
    end
    assert_equal("\n\n", output)
  end

  def test_puts_instancemethod_no_args
    cls, = compile(%q{
      class Foo
        def foo
          puts
          puts
          puts
        end
      end
    })
    output = capture_output do
      cls.new.foo
    end
    assert_equal("\n\n\n", output)
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
      def foo(a:int)
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
      def foo(a:int)
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
      def foo(a:int)
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
        'def foo(a:int);while a > 0; a -= 1; puts ".";end;end')
    assert_equal('', capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})

    cls, = compile(
        'def foo(a:int);begin;a -= 1; puts ".";end while a > 0;end')
    assert_equal(".\n", capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})

    cls, = compile(
        'def foo(a:int);until a <= 0; a -= 1; puts ".";end;end')
    assert_equal('', capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})

    cls, = compile(
        'def foo(a:int);begin;a -= 1; puts ".";end until a <= 0;end')
    assert_equal(".\n", capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})

    cls, = compile(
        'def foo; a = 0; while a < 2; a+=1; end; end')
    assert_equal(nil, cls.foo)

    # TODO: loop doesn't work unless you're explicitly in a class
    # cls, = compile(<<-EOF)
    #   def bar(a:int)
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
      def bar(a:int)
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
        def initialize(a:int)
          @a = a
        end

        def a
          @a
        end

        def self.set_b(b:int)
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

  def test_argument_boxing
    [ [:short], [:int,:integer], [:long], [:byte]].each do |types|
      primitive, full = types.first, types.last
      begin
        cls, = compile(<<-EOF)
        def to_#{primitive}(a:#{full.to_s.capitalize}):void
          puts a
        end
        to_#{primitive} #{primitive}(1)
        EOF
        assert_run_output("1\n", cls)
      rescue => e
        raise "#{primitive} #{e.message}"
      end
    end
    %w[float double].each do |type|
      begin
      cls, = compile(<<-EOF)
        def to_#{type}(a:#{type.to_s.capitalize}):void
          puts a
        end
        to_#{type} #{type}(1)
        EOF
      assert_run_output("1.0\n", cls)
      rescue => e
        raise "#{type} #{e.message}"
      end
    end

    cls, = compile(<<-EOF)
      def to_character(a:Character):void
        puts a
      end
      to_character char(65)
    EOF
    assert_run_output("A\n", cls)
  end

  def test_return_boxing_and_unboxing
    cls, = compile(<<-EOF)
      def box:Boolean
        return true
      end

      def unbox:boolean
        return Boolean.new(false)
      end

    EOF
    assert_equal(true, cls.box)
    assert_equal(false, cls.unbox)
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
  
  def test_promotion_to_boolean
    cases = [
      [ "String",  "a"  => true, nil   => false ],
      [ "boolean", true => true, false => false ],
      [ "byte",    1    => true, 0     => true  ],
      [ "short",   1    => true, 0     => true  ],
      [ "int",     1    => true, 0     => true  ],
      [ "long",    1    => true, 0     => true  ],
      [ "char",    1    => true, 0     => true  ],
      [ "float",   1.0  => true, 0.0   => true  ],
      [ "double",  1.0  => true, 0.0   => true  ],
    ].each do |type, cases|
      cls, = compile(%Q[
        class Foo
          def self.foo(a:#{type})
            if a
              true
            else
              false
            end
          end
          def self.foo_inverted(a:#{type})
            unless a
              true
            else
              false
            end
          end
        end
      ])
      cases.each do |input,boolean_value|
        assert_equal( boolean_value, cls.foo(input))
        assert_equal(!boolean_value, cls.foo_inverted(input))
      end
    end
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
        puts n
        x
      end

      def foo(a:boolean, b:boolean)
        return bool('a', a) && bool('b', b)
      end

      def str(n:String, x:String)
        puts n
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
        puts n
        x
      end

      def foo(a:boolean, b:boolean)
        return bool('a', a) || bool('b', b)
      end

      def str(n:String, x:String)
        puts n
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
    pend_on_jruby("1.7.13") do

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
  end

  def test_literal_array
    cls, = compile(<<-EOF)
      def foo; puts "hello"; nil; end
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
        puts split
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

      puts A1.new.foo("Hi")
      puts B1.new.foo("There")
    EOF

    assert_run_output("Hi\nThere\n", cls)
  end

  def test_super
    cls, = compile(<<-EOF)
      class SuperEqual
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
        puts a; puts b; puts c
      end
      foo(0)
      foo(0,0)
      foo(0,0,0)
    EOF
    assert_run_output("0\n1\n2\n0\n0\n2\n0\n0\n0\n", cls)
  end

  def test_field_read
    cls, = compile(<<-EOF)
      puts System.out.getClass.getName
    EOF
    assert_run_output("java.io.PrintStream\n", cls)
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
    assert_run_output("oranges oranges", cls)
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

  def test_lowercase_inner_class
    cls, = compile(<<-EOF)
      import org.foo.LowerCaseInnerClass

      def foo
        LowerCaseInnerClass.inner.field
      end
    EOF

    assert_equal(1234, cls.foo)
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
#    assert_run_output("3.0\n", cls)
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

  def test_return_type
    assert_raise_kind_of Mirah::MirahError do
      compile(<<-EOF)
        class ReturnsA
          def a:int
            :foo
          end
        end
      EOF
    end

    assert_raise_kind_of Mirah::MirahError do
      compile(<<-EOF)
        class ReturnsB
          def self.a:String
            2
          end
        end
      EOF
    end
  end

  def test_native
    cls, = compile(<<-EOF)
      class Foo
        native def foo; end
      end
    EOF

    assert_raise_java java.lang.UnsatisfiedLinkError do
      a = cls.new
      a.foo
    end
  end

  def test_abstract
    abstract_class, concrete_class = compile(<<-EOF)
      abstract class Abstract
        abstract def foo:void; end
        def bar; puts "bar"; end
      end
      class Concrete < Abstract
        def foo; puts :foo; end
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

  def test_synchronized
    cls, = compile(<<-EOF)
      class Synchronized
        attr_accessor locked:boolean
        
        synchronized def lock_and_unlock:void
          puts "Locking."
          Thread.sleep(100)
          self.locked = true
          puts "Waiting."
          self.wait
          puts "Unlocking."
          self.locked = false
        end
        
        synchronized def locked?
          self.locked
        end
        
        synchronized def notify_synchronized:void
          puts "Notifying."
          self.notify
          puts "Notified."
        end
        
        def trigger:void
          while ! locked?
            Thread.sleep(10)
          end
          self.notify_synchronized
        end
        
        def start_trigger
          s = self
          Thread.new do
            s.trigger
          end.start
        end
      end
    EOF

    assert_output("Locking.\nWaiting.\nNotifying.\nNotified.\nUnlocking.\n") do
      a = cls.new
      a.start_trigger
      a.lock_and_unlock
    end
  end

  def test_return_void
    script, = compile(<<-EOF)
      def foo:void
        puts :hi
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
          puts a
          puts b.getMessage
        end
        puts b
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

  def test_colon2_constant_ref
    cls, = compile(<<-EOF)
      def foo
        Character::UnicodeBlock::ARROWS
      end
    EOF

    subset = cls.foo
    assert_equal("java.lang.Character$UnicodeBlock", subset.java_class.name)
  end

  def test_covariant_arrays
    cls, = compile(<<-EOF)
      puts java::util::Arrays.toString(String[5])
    EOF

    assert_run_output("[null, null, null, null, null]\n", cls)
  end

  def test_getClass_on_object_array
    cls, = compile(<<-EOF)
      puts Object[0].getClass.getName
    EOF

    assert_run_output("[Ljava.lang.Object;\n", cls)
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
      puts Object(a)
    EOF

    assert_run_output("null\n", cls)
  end

  def test_long_generation
    cls, = compile(<<-EOF)
      c = 2_000_000_000_000
      puts c
    EOF
  end


  def test_inconvertible_classes_cause_cast_error
    pend "waiting on better error picking" do
      ex = assert_raise Mirah::MirahError  do
        compile(<<-EOF)
        class A;end
        class B;end
        def f(a:A): B
          B(a)
        end
        EOF
      end
      assert_equal("Cannot cast A to B.", ex.message)
    end
  end

  def test_inconvertible_default_classes_cause_cast_error
    pend "waiting on better error picking" do
      ex = assert_raise Mirah::MirahError  do
        compile(<<-EOF)
        import java.lang.Integer
        java.lang.Integer("a string")
        EOF
      end
      assert_equal("Cannot cast java.lang.Integer to java.lang.String.", ex.message)
    end
  end

  def test_casting_up_should_work
    cls, = compile(<<-EOF)
    puts Object("a string")
    EOF
    assert_run_output("a string\n", cls)
  end

  def test_missing_class_with_block_raises_inference_error
    # TODO(ribrdb): What is this test for?
    ex = assert_raise Mirah::MirahError  do
      compile("Interface Implements_Go do; end")
    end
    assert_equal("Cannot find class Implements_Go", ex.message)
  end

  def test_bool_equality
    cls, = compile("puts true == false")
    assert_run_output("false\n", cls)
  end

  def test_bool_inequality
    cls, = compile("puts true != false")
    assert_run_output("true\n", cls)
  end

  def test_double_equals_calls_equals_when_first_arg_not_nil
    cls, = compile(<<-EOF)
      class DoubleEqualsCalling
        def equals(other)
          puts "called"
          true
        end
      end
      DoubleEqualsCalling.new == nil
    EOF
    assert_run_output("called\n", cls)
  end

  def test_double_equals_does_not_call_equals_when_first_arg_nil
    cls, = compile(<<-EOF)
      class DoubleEqualsCalling2
        def equals(other)
          puts "called"
          true
        end
      end
      nil == DoubleEqualsCalling2.new
    EOF
    assert_run_output("", cls)
  end

  def test_double_equals_nil_literal_equals_nil_literal
    cls, = compile(<<-EOF)
      puts nil == nil
    EOF
    assert_run_output("true\n", cls)
  end

  def test_double_equals_nil_ref_equals_nil_literal
    cls, = compile(<<-EOF)
      a = nil
      puts a == nil
    EOF
    assert_run_output("true\n", cls)
  end

  def test_double_equals_cast_nil_ref_equals_nil_literal
    cls, = compile(<<-EOF)
      a = Object(nil)
      puts a == nil
    EOF
    assert_run_output("true\n", cls)
  end

  def test_double_equals_compare_to_self_in_a_equals_method_def_has_warning
    cls = nil
    output = capture_output do
      cls, = compile(<<-EOF)
        class DoubleEqualsSelf
          def equals(other)
            other == self
          end
        end
        puts DoubleEqualsSelf.new == nil
      EOF
    end
    assert_include(
      "WARNING: == is now an alias for Object#equals(), === is now used for identity.\n" +
      "This use of == with self in equals() definition may cause a stack overflow in next release!",
      output)
    assert_run_output("false\n", cls)
  end

  def test_double_equals_compare_to_self_in_a_equals_method_def_warning_includes_source
    cls = nil
    output = capture_output do
      cls, = compile(<<-EOF)
        class DoubleEqualsSelf
          def equals(other)
            other == self
          end
        end
        puts DoubleEqualsSelf.new == nil
      EOF
    end
    assert_include(
"          def equals(other)
            other == self
          end", output)
    assert_run_output("false\n", cls)
  end

  def test_double_equals_self_compare_to_other_in_a_equals_method_def_has_warning
    cls = nil
    output = capture_output do
      cls, = compile(<<-EOF)
        class SelfDoubleEqualsOther
          def equals(other)
            self == other
          end
        end
        puts SelfDoubleEqualsOther.new == nil
      EOF
    end
    assert_include(
      "WARNING: == is now an alias for Object#equals(), === is now used for identity.\n" +
      "This use of == with self in equals() definition may cause a stack overflow in next release!",
      output)
    assert_run_output("false\n", cls)
  end

  def test_triple_equals_with_ints
    cls, = compile(<<-EOF)
      puts 1 === 1
      puts 1 === 2
      puts 1 !== 2
      puts 1 !== 1
    EOF
    assert_run_output("true\nfalse\ntrue\nfalse\n", cls)
  end

  def test_triple_equals_with_objects
    cls, = compile(<<-EOF)
      a = Object.new
      b = Object.new
      puts a === a
      puts a === b
      puts a !== b
      puts a !== a
    EOF
    assert_run_output("true\nfalse\ntrue\nfalse\n", cls)
  end

  def test_triple_equals_with_arrays
    cls, = compile(<<-EOF)
      a = Object[1]
      b = Object[1]
      puts a === a
      puts a === b
      puts a !== b
      puts a !== a
    EOF
    assert_run_output("true\nfalse\ntrue\nfalse\n", cls)
  end

  def test_double_equals_with_arrays
    cls, = compile(<<-EOF)
      a = Object[1]
      b = Object[1]
      puts a == a
      puts a == b
      puts a != b
      puts a != a
    EOF
    assert_run_output("true\ntrue\nfalse\nfalse\n", cls)
  end

  def test_field_setter_with_nil
    cls, = compile(<<-EOF)
      class FieldSetter
        attr_accessor field: String
      end
      a = FieldSetter.new
      a.field = nil
      print "OK"
    EOF
    
    assert_run_output("OK", cls)
  end

  def test_assign_int_to_double
    cls, = compile(<<-EOF)
      def foo
        a = 1.0
        a = 0
      end
    EOF
    
    assert_equal(0.0, cls.foo)
  end

  def test_assign_int_to_double_with_additional_assign_is_int
    cls, = compile(<<-EOF)
      def foo
        a = 1.0
        b = a = 0
      end
    EOF
    assert(cls.foo.is_a? Fixnum)
    assert_equal(0, cls.foo)
  end

  def test_assign_int_to_double_with_additional_assign_and_specified_return_as_double_is_double
    cls, = compile(<<-EOF)
      def foo : double
        a = 1.0
        b = a = 0
      end
    EOF
    assert(cls.foo.is_a? Float)
    assert_equal(0, cls.foo)
  end

  def test_return_int_when_specified_return_as_double_is_double
    cls, = compile(<<-EOF)
      def foo : double
        0
      end
    EOF
    assert(cls.foo.is_a? Float)
    assert_equal(0, cls.foo)
  end

  def test_assign_int_to_double_in_closure
    cls, = compile(<<-EOF)
      def bar(r:Runnable); r.run; end

      def foo
        a = 1.0
        bar do
          a = 0
        end
        a
      end
    EOF

    assert_equal(0.0, cls.foo)
  end

  def test_array_literals_are_modifiable
    cls, = compile(<<-EOF)
      def foo
        arr = [1,2]
        arr.add(3)
        arr[2]
      end
    EOF

    assert_equal(3, cls.foo)
  end

  def test_static_method_inheritance
    cls, = compile(<<-EOF)
      class Parent
        def self.my_method
          'ran my method'
        end
      end

      class Child < Parent
      end

      puts Child.my_method
    EOF

    assert_run_output("ran my method\n", cls)
  end

  def test_incompatible_meta_change
    cls, = compile(<<-EOF)
      class A < B
        def foo(a:Object)
          a.kind_of?(A)
        end
      end

      class B
      end
    EOF
    
    a = cls.new
    assert(a.foo(a))
  end

  def test_local_method_conflict
    cls, arg = compile(<<-EOF)
      def a; ArgType.new; end
      def foo(a:ArgType):void
        x = Object[ a ? a.bar : 0]
        puts x.length
      end
      
      class ArgType
        def bar
          2
        end
      end
    EOF

    assert_output("0\n") { cls.foo(nil)}
    assert_output("2\n") { cls.foo(arg.new)}
  end
  
  def test_local_method_conflict2
    cls, arg = compile(%q{
      
      class Foo1
        
        def equals(o:Foo1)
          self===o
        end
      end
      
      class Bar
        attr_reader   foo1:Foo1
        attr_reader   foo2:Foo2
        
        def foo1method(foo1:Foo1)
          puts (@foo1==foo1)
          @foo1 = foo1
        end
        
        def foo2method(foo2:Foo2)
          puts (@foo2==foo2)
          @foo2 = foo2
        end
      end
      
      class Foo2
        
        def equals(o:Foo2)
          self===o
        end
      end
      
      Bar.new.foo1method(Foo1.new)
      Bar.new.foo2method(Foo2.new)
    })
    assert_run_output("false\nfalse\n", cls)
  end

  def test_incompatible_return_type_error_message
    e = assert_raise_kind_of Mirah::MirahError do
      compile(<<-EOF)
      def a: int
        return 1.2 if true
        1
      end
      EOF
    end
    assert_equal "Invalid return type double, expected int",e.message
  end

  def test_inner_interface
    cls, arg = compile(%q{
      
      class Foo1
        
        interface Bar
          def baz:String; end
        end
        
        class Foo2 implements Bar
          def baz
            "BAZ"
          end
        end
      end
      

      puts Foo2.new.baz
    })
    assert_run_output("BAZ\n", cls)
  end
  
  def test_line_number_increase_by_multiline_sstring_literal
    e = assert_raise_kind_of Mirah::MirahError do
      cls, arg = compile(%q{
        class Foo
          CONST = 'a
        
        
        
          b'
        end
        
        
        ERROR_SHOULD_BE_HERE
      })
    end
    assert_equal 11,e.diagnostic.getLineNumber
  end
  
  def test_line_number_increase_by_multiline_dstring_literal
    e = assert_raise_kind_of Mirah::MirahError do
      cls, arg = compile(%q{
        class Foo
          CONST = "a
        
        
        
          b"
        end
        
        
        ERROR_SHOULD_BE_HERE
      })
    end
    assert_equal 11,e.diagnostic.getLineNumber
  end

  def test_late_superclass
    cls, arg = compile(%q{
      package subclass_test
      
      class TestSubclassAsMethodParameter
        def bar(b:SuperClass)
          "baz"
        end
      
        def foo
          a = SubClass.new
          bar(a)
        end 
      end
      
      class SubClass < SuperClass
      end
      
      class SuperClass
      end
      
      puts TestSubclassAsMethodParameter.new.foo
    })
    assert_run_output("baz\n", cls)
  end
  
  def test_late_superinterface
    cls, arg = compile(%q{
      package late_superinterface
      
      interface Interface2 < Interface1
      end
      
      interface Interface3 < Interface2
      end
      
      interface Interface1
      end
    })
  end

  def test_init_before_use_in_loop
    cls, arg = compile(%q{
      macro def loop_with_init(block:Block)
        i = block.arguments.required(0).name.identifier
        last = gensym
        quote do
          while `i` < `last`
            init { `i` = 0; `last` = 4}
            post { `i` = `i` + 1 }
            `block.body`
          end
        end
      end
      loop_with_init do |i|
        print i
      end
    })
    assert_run_output("0123", cls)
  end

  def test_filename_shows_up_in_exception_upon_syntax_error
    begin
      foo, = compile("puts('foo',)", name: 'somespecificfilename.mirah')
      assert false
    rescue => e
      assert e.message.match(/somespecificfilename/)
    end
  end
end
