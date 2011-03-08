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

$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'mirah'
require 'jruby'
require 'stringio'
require 'fileutils'

unless Mirah::AST.macro "__gloop__"
  Mirah::AST.defmacro "__gloop__" do |transformer, fcall, parent|
    Mirah::AST::Loop.new(parent, parent.position, true, false) do |loop|
      init, condition, check_first, pre, post = fcall.parameters
      loop.check_first = check_first.literal

      nil_t = Mirah::AST::Null
      loop.init = init
      loop.pre = pre
      loop.post = post

      body = fcall.block.body
      body.parent = loop
      [
        Mirah::AST::Condition.new(loop, parent.position) do |c|
          condition.parent = c
          [condition]
        end,
        body
      ]
    end
  end
end

class TestJVMCompiler < Test::Unit::TestCase
  include Mirah
  import java.lang.System
  import java.io.PrintStream

  def setup
    @tmp_classes = []
  end

  def teardown
    AST.type_factory = nil
    File.unlink(*@tmp_classes)
  end

  def assert_include(value, array, message=nil)
    message = build_message message, '<?> does not include <?>', array, value
    assert_block message do
      array.include? value
    end
  end

  def compile(code)
    File.unlink(*@tmp_classes)
    @tmp_classes.clear
    AST.type_factory = Mirah::JVM::Types::TypeFactory.new
    name = "script" + System.nano_time.to_s
    state = Mirah::CompilationState.new
    state.save_extensions = false
    transformer = Mirah::Transform::Transformer.new(state)
    Java::MirahImpl::Builtin.initialize_builtins(transformer)
    ast  = AST.parse(code, name, true, transformer)
    typer = Typer::JVM.new(transformer)
    ast.infer(typer, true)
    typer.resolve(true)
    compiler = Compiler::JVM.new
    compiler.compile(ast)
    classes = {}
    loader = MirahClassLoader.new(JRuby.runtime.jruby_class_loader, classes)
    compiler.generate do |name, builder|
      bytes = builder.generate
      FileUtils.mkdir_p(File.dirname(name))
      open("#{name}", "wb") do |f|
        f << bytes
      end
      classes[name[0..-7]] = bytes
    end

    classes.keys.map do |name|
      cls = loader.load_class(name.tr('/', '.'))
      proxy = JavaUtilities.get_proxy_class(cls.name)
      @tmp_classes << "#{name}.class"
      proxy
    end
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
        throws IOException
        OutputStreamWriter.new(
            System.out).write("Hello ").write("there\n").flush
      end
    EOF

    assert_output("Hello there\n") { cls.foo }

    script, a, b = compile(<<-EOF)
      class VoidBase
        def foo
          returns void
          puts "foo"
        end
      end
      class VoidChain < VoidBase
        def bar
          returns void
          puts "bar"
        end

        def self.foobar
          VoidChain.new.foo.bar
        end
      end
    EOF

    assert_output("foo\nbar\n") { b.foobar }

  end

  def test_import
    cls, = compile("import 'AL', 'java.util.ArrayList'; def foo; AL.new; end; foo")
    assert_equal java.util.ArrayList.java_class, cls.foo.java_class

    cls, = compile("import 'java.util.ArrayList'; def foo; ArrayList.new; end; foo")
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
        throws Exception
        a.call
      end
    EOF
    result = cls.foo {0}
    assert_equal 0, result
    m = cls.java_class.java_method 'foo', java.util.concurrent.Callable
    assert_equal([java.lang.Exception.java_class], m.exception_types)

  end

  def test_class_decl
    foo, = compile("class ClassDeclTest;end")
    assert_equal('ClassDeclTest', foo.java_class.name)
  end

  def capture_output
    saved_output = System.out
    output = StringIO.new
    System.setOut(PrintStream.new(output.to_outputstream))
    begin
      yield
      output.rewind
      output.read
    ensure
      System.setOut(saved_output)
    end
  end

  def assert_output(expected, &block)
    assert_equal(expected, capture_output(&block))
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

  def test_constructor
    cls, = compile(
        "class InitializeTest;def initialize;puts 'Constructed';end;end")
    assert_output("Constructed\n") do
      cls.new
    end
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


  def test_local_decl
    cls, = compile(<<-EOF)
      import 'java.lang.String'
      a = :fixnum
      b = :int
      c = :long
      d = :float
      e = :string
      f = String
      puts a
      puts b
      puts c
      puts d
      puts e
      puts f
    EOF
    output = capture_output do
      cls.main([].to_java(:string))
    end
    assert_equal("0\n0\n0\n0.0\nnull\nnull\n", output)
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
        'def foo(a:fixnum);while a > 0; a -= 1; puts ".";end;end')
    assert_equal('', capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})

    cls, = compile(
        'def foo(a:fixnum);begin;a -= 1; puts ".";end while a > 0;end')
    assert_equal(".\n", capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})

    cls, = compile(
        'def foo(a:fixnum);until a <= 0; a -= 1; puts ".";end;end')
    assert_equal('', capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})

    cls, = compile(
        'def foo(a:fixnum);begin;a -= 1; puts ".";end until a <= 0;end')
    assert_equal(".\n", capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})

    cls, = compile(
        'def foo; a = 0; while a < 2; a+=1; end; end')
    assert_equal(nil, cls.foo)
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
    script, cls = compile(<<-EOF)
      import java.lang.Iterable
      class Foo; implements Iterable
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
    script, interface = compile('interface A do; end')
    assert(interface.java_class.interface?)
    assert_equal('A', interface.java_class.name)

    script, a, b = compile('interface A do; end; interface B < A do; end')
    assert_include(a, b.ancestors)
    assert_equal('A', a.java_class.name)
    assert_equal('B', b.java_class.name)

    script, a, b, c = compile(<<-EOF)
      interface A do
      end

      interface B do
      end

      interface C < A, B do
      end
    EOF

    assert_include(a, c.ancestors)
    assert_include(b, c.ancestors)
    assert_equal('A', a.java_class.name)
    assert_equal('B', b.java_class.name)
    assert_equal('C', c.java_class.name)

    assert_raise Mirah::Typer::InferenceError do
      compile(<<-EOF)
        interface A do
          def a
            returns :int
          end
        end

        class Impl; implements A
          def a
            "foo"
          end
        end
      EOF
    end
  end

  def assert_throw(type, message="")
    ex = assert_raise(NativeException) do
      yield
    end
    assert_equal type, ex.cause.class
    assert_equal message, ex.cause.message.to_s
  end

  def test_raise
    cls, = compile(<<-EOF)
      def foo
        raise
      end
    EOF
    assert_throw(java.lang.RuntimeException) do
      cls.foo
    end

    cls, = compile(<<-EOF)
      def foo
        raise "Oh no!"
      end
    EOF
    ex = assert_throw(java.lang.RuntimeException, 'Oh no!') do
      cls.foo
    end

    cls, = compile(<<-EOF)
      def foo
        raise IllegalArgumentException
      end
    EOF
    ex = assert_throw(java.lang.IllegalArgumentException) do
      cls.foo
    end

    cls, = compile(<<-EOF)
      def foo
        throws Exception
        raise Exception, "oops"
      end
    EOF
    ex = assert_throw(java.lang.Exception, "oops") do
      cls.foo
    end

    cls, = compile(<<-EOF)
      def foo
        throws Throwable
        raise Throwable.new("darn")
      end
    EOF
    ex = assert_throw(java.lang.Throwable, "darn") do
      cls.foo
    end
  end

  def test_rescue
    cls, = compile(<<-EOF)
      def foo
        begin
          puts "body"
        rescue
          puts "rescue"
        end
      end
    EOF

    output = capture_output do
      cls.foo
    end
    assert_equal("body\n", output)

    cls, = compile(<<-EOF)
      def foo
        begin
          puts "body"
          raise
        rescue
          puts "rescue"
        end
      end
    EOF

    output = capture_output do
      cls.foo
    end
    assert_equal("body\nrescue\n", output)

    cls, = compile(<<-EOF)
      def foo(a:int)
        begin
          puts "body"
          if a == 0
            raise IllegalArgumentException
          else
            raise
          end
        rescue IllegalArgumentException
          puts "IllegalArgumentException"
        rescue
          puts "rescue"
        end
      end
    EOF

    output = capture_output do
      cls.foo(1)
      cls.foo(0)
    end
    assert_equal("body\nrescue\nbody\nIllegalArgumentException\n", output)

    cls, = compile(<<-EOF)
      def foo(a:int)
        begin
          puts "body"
          if a == 0
            raise IllegalArgumentException
          elsif a == 1
            raise Throwable
          else
            raise
          end
        rescue IllegalArgumentException, RuntimeException
          puts "multi"
        rescue Throwable
          puts "other"
        end
      end
    EOF

    output = capture_output do
      cls.foo(0)
      cls.foo(1)
      cls.foo(2)
    end
    assert_equal("body\nmulti\nbody\nother\nbody\nmulti\n", output)

    cls, = compile(<<-EOF)
      def foo
        begin
          raise "foo"
        rescue => ex
          puts ex.getMessage
        end
      end
    EOF

    output = capture_output do
      cls.foo
    end
    assert_equal("foo\n", output)
  end

  def test_ensure
    cls, = compile(<<-EOF)
      def foo
        1
      ensure
        puts "Hi"
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
        puts "Hi"
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
          puts "Hi"
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

  def test_for
    cls, = compile(<<-EOF)
      def foo
        a = int[3]
        count = 0
        for x in a
          count += 1
        end
        count
      end
    EOF

    cls, = compile(<<-EOF)
      def foo(a:int[])
        count = 0
        for x in a
          count += x
        end
        count
      end
    EOF

    assert_equal(9, cls.foo([2, 3, 4].to_java(:int)))

    cls, = compile(<<-EOF)
      def foo(a:Iterable)
        a.each do |x|
          puts x
        end
      end
    EOF

    assert_output("1\n2\n3\n") do
      list = java.util.ArrayList.new
      list << "1"
      list << "2"
      list << "3"
      cls.foo(list)
    end

    cls, = compile(<<-EOF)
      import java.util.ArrayList
      def foo(a:ArrayList)
        a.each do |x|
          puts x
        end
      end
    EOF

    assert_output("1\n2\n3\n") do
      list = java.util.ArrayList.new
      list << "1"
      list << "2"
      list << "3"
      cls.foo(list)
    end

    cls, = compile(<<-EOF)
      def foo(a:int[])
        a.each {|x| x += 1;puts x; redo if x == 2}
      end
    EOF

    assert_output("2\n3\n3\n4\n") do
      cls.foo([1,2,3].to_java(:int))
    end
  end

  def test_all
    cls, = compile(<<-EOF)
      def foo(a:int[])
        a.all? {|x| x % 2 == 0}
      end
    EOF

    assert_equal(false, cls.foo([2, 3, 4].to_java(:int)))
    assert_equal(true, cls.foo([2, 0, 4].to_java(:int)))

    cls, = compile(<<-EOF)
      def foo(a:String[])
        a.all?
      end
    EOF

    assert_equal(true, cls.foo(["a", "", "b"].to_java(:string)))
    assert_equal(false, cls.foo(["a", nil, "b"].to_java(:string)))
  end

  def test_downto
    cls, = compile(<<-EOF)
      def foo(i:int)
        i.downto(1) {|x| puts x }
      end
    EOF

    assert_output("3\n2\n1\n") do
      cls.foo(3)
    end
  end

  def test_upto
    cls, = compile(<<-EOF)
      def foo(i:int)
        i.upto(3) {|x| puts x }
      end
    EOF

    assert_output("1\n2\n3\n") do
      cls.foo(1)
    end
  end

  def test_times
    cls, = compile(<<-EOF)
      def foo(i:int)
        i.times {|x| puts x }
      end
    EOF

    assert_output("0\n1\n2\n") do
      cls.foo(3)
    end

    cls, = compile(<<-EOF)
      def foo(i:int)
        i.times { puts "Hi" }
      end
    EOF

    assert_output("Hi\nHi\nHi\n") do
      cls.foo(3)
    end
  end

  def test_general_loop
    cls, = compile(<<-EOF)
      def foo(x:boolean)
        a = ""
        __gloop__(nil, x, true, nil, nil) {a += "<body>"}
        a
      end
    EOF
    assert_equal("", cls.foo(false))

    cls, = compile(<<-EOF)
      def foo
        a = ""
        __gloop__(nil, false, false, nil, nil) {a += "<body>"}
        a
      end
    EOF
    assert_equal("<body>", cls.foo)

    cls, = compile(<<-EOF)
      def foo(x:boolean)
        a = ""
        __gloop__(a += "<init>", x, true, a += "<pre>", a += "<post>") do
          a += "<body>"
        end
        a
      end
    EOF
    assert_equal("<init>", cls.foo(false))

    cls, = compile(<<-EOF)
      def foo
        a = ""
        __gloop__(a += "<init>", false, false, a += "<pre>", a += "<post>") do
          a += "<body>"
        end
        a
      end
    EOF
    assert_equal("<init><pre><body><post>", cls.foo)

    cls, = compile(<<-EOF)
      def foo
        a = ""
        __gloop__(a += "<init>", false, false, a += "<pre>", a += "<post>") do
          a += "<body>"
          redo if a.length < 20
        end
        a
      end
    EOF
    assert_equal( "<init><pre><body><body><post>", cls.foo)

    cls, = compile(<<-EOF)
      def foo
        a = ""
        __gloop__(a += "<init>", a.length < 20, true, a += "<pre>", a += "<post>") do
          next if a.length < 17
          a += "<body>"
        end
        a
      end
    EOF
    assert_equal("<init><pre><post><pre><body><post>", cls.foo)
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

  def test_constructor_chaining
    foo, = compile(<<-EOF)
      class Foo5
        def initialize(s:String)
          initialize(s, "foo")
        end

        def initialize(s:String, f:String)
          @s = s
          @f = f
        end

        def f
          @f
        end

        def s
          @s
        end
      end
    EOF

    instance = foo.new("S")
    assert_equal("S", instance.s)
    assert_equal("foo", instance.f)

    instance = foo.new("foo", "bar")
    assert_equal("foo", instance.s)
    assert_equal("bar", instance.f)
  end

  def test_super_constructor
    cls, a, b = compile(<<-EOF)
      class SC_A
        def initialize(a:int)
          puts "A"
        end
      end

      class SC_B < SC_A
        def initialize
          super(0)
          puts "B"
        end
      end
    EOF

    assert_output("A\nB\n") do
      b.new
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

  def test_empty_constructor
    foo, = compile(<<-EOF)
      class Foo6
        def initialize; end
      end
    EOF
    foo.new
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

    assert_output("Hi\nThere\n") do
      cls.main(nil)
    end
  end

  def test_annotations
    deprecated = java.lang.Deprecated.java_class
    cls, = compile(<<-EOF)
      $Deprecated
      def foo
        'foo'
      end
    EOF

    assert_not_nil cls.java_class.java_method('foo').annotation(deprecated)
    assert_nil cls.java_class.annotation(deprecated)

    script, cls = compile(<<-EOF)
      $Deprecated
      class Annotated
      end
    EOF
    assert_not_nil cls.java_class.annotation(deprecated)

    cls, = compile(<<-EOF)
      class AnnotatedField
        def initialize
          $Deprecated
          @foo = 1
        end
      end
    EOF

    assert_not_nil cls.java_class.declared_fields[0].annotation(deprecated)
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

  def test_inexact_constructor
    # FIXME: this is a stupid test
    cls, = compile(
        "class EmptyEmpty; def self.empty_empty; t = Thread.new(Thread.new); t.start; begin; t.join; rescue InterruptedException; end; puts 'ok'; end; end")
    assert_output("ok\n") do
      cls.empty_empty
    end
  end

  def test_method_lookup_with_overrides
    cls, = compile(<<-EOF)
      class Bar; implements Runnable
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

  def test_block
    cls, = compile(<<-EOF)
      thread = Thread.new do
        puts "Hello"
      end
      begin
        thread.run
        thread.join
      rescue
        puts "Uh Oh!"
      end
    EOF
    assert_output("Hello\n") do
      cls.main([].to_java :string)
    end

    script, cls = compile(<<-EOF)
      import java.util.Observable
      class MyObservable < Observable
        def initialize
          super
          setChanged
        end
      end

      o = MyObservable.new
      o.addObserver {|x, a| puts a}
      o.notifyObservers("Hello Observer")
    EOF
    assert_output("Hello Observer\n") do
      script.main([].to_java :string)
    end

    cls, = compile(<<-EOF)
      def foo
        a = "Hello"
        thread = Thread.new do
          puts a
        end
        begin
          a = a + " Closures"
          thread.run
          thread.join
        rescue
          puts "Uh Oh!"
        end
        return
      end
    EOF
    assert_output("Hello Closures\n") do
      cls.foo
    end

    cls, = compile(<<-EOF)
      def run(x:Runnable)
        x.run
      end
      def foo
        a = 1
        run {a += 1}
        a
      end
    EOF
    assert_equal(2, cls.foo)
  end

  def test_block_with_method_def
    cls, = compile(<<-EOF)
      import java.util.ArrayList
      import java.util.Collections
      list = ArrayList.new(["a", "ABC", "Cats", "b"])
      Collections.sort(list) do
        def equals(a:Object, b:Object)
          String(a).equalsIgnoreCase(String(b))
        end
        def compare(a:Object, b:Object)
          String(a).compareToIgnoreCase(String(b))
        end
      end
      list.each {|x| puts x}
    EOF

    assert_output("a\nABC\nb\nCats\n") do
      cls.main(nil)
    end
  end

  def test_each
    cls, = compile(<<-EOF)
      def foo
        [1,2,3].each {|x| puts x}
      end
    EOF
    assert_output("1\n2\n3\n") do
      cls.foo
    end
  end

  def test_any
    cls, = compile(<<-EOF)
      import java.lang.Integer
      def foo
        puts [1,2,3].any?
        puts [1,2,3].any? {|x| Integer(x).intValue > 3}
      end
    EOF
    assert_output("true\nfalse\n") do
      cls.foo
    end
  end

  def test_all
    cls, = compile(<<-EOF)
      import java.lang.Integer
      def foo
        puts [1,2,3].all?
        puts [1,2,3].all? {|x| Integer(x).intValue > 3}
      end
    EOF
    assert_output("true\nfalse\n") do
      cls.foo
    end
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
    assert_output("0\n1\n2\n0\n0\n2\n0\n0\n0\n") do
      cls.main([].to_java :string)
    end
  end

  def test_field_read
    cls, = compile(<<-EOF)
      puts System.out.getClass.getName
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

  def test_block_with_duby_interface
    cls, interface = compile(<<-EOF)
      interface MyProc do
        def call; returns :void; end
      end
      def foo(b:MyProc)
        b.call
      end
      def bar
        foo {puts "Hi"}
      end
    EOF
    assert_output("Hi\n") do
      cls.bar
    end
  end

  def test_duby_iterable
    script, cls = compile(<<-EOF)
      import java.util.Iterator
      class MyIterator; implements Iterable, Iterator
        def initialize(x:Object)
          @next = x
        end

        def hasNext
          @next != nil
        end

        def next
          result = @next
          @next = nil
          result
        end

        def iterator
          self
        end

        def remove
          raise UnsupportedOperationException
        end

        def self.test(x:String)
          MyIterator.new(x).each {|y| puts y}
        end
      end
    EOF
    assert_output("Hi\n") do
      cls.test("Hi")
    end
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
        print "Hello \#{name}."
      end
    EOF

    assert_output("Hello Fred.") do
      cls.foo "Fred"
    end

    cls, = compile(<<-EOF)
      def foo(x:int)
        print "\#{x += 1}"
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
        print "\#{a}, \#{b}, \#{c}"
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
        Character.UnicodeBlock.ARROWS
      end
    EOF

    subset = cls.foo
    assert_equal("java.lang.Character$UnicodeBlock", subset.java_class.name)
  end

  def test_defmacro
    cls, = compile(<<-EOF)
      defmacro bar(x) do
        x
      end
      
      def foo
        bar("bar")
      end
    EOF

    assert_equal("bar", cls.foo)
    assert(!cls.respond_to?(:bar))
  end

  def test_default_constructor
    script, cls = compile(<<-EOF)
      class DefaultConstructable
        def foo
          "foo"
        end
      end

      print DefaultConstructable.new.foo
    EOF

    assert_output("foo") do
      script.main(nil)
    end
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

      def dynamic(c:Class, o:Object)
        o.kind_of?(c)
      end
    EOF

    assert_equal(true, cls.string("foo"))
    assert_equal(false, cls.string(2))
    assert_equal(true, cls.dynamic(java.lang.String, "foo"))
    assert_equal(true, cls.dynamic(java.lang.Object, "foo"))
    assert_equal(false, cls.dynamic(java.lang.Object, nil))
  end

  def test_instance_macro
    # TODO fix annotation output and create a duby.anno.Extensions annotation.
    return if self.class.name == 'TestJavacCompiler'
    script, cls = compile(<<-EOF)
      class InstanceMacros
        def foobar
          "foobar"
        end

        macro def macro_foobar
          quote {foobar}
        end
      
        def call_foobar
          macro_foobar
        end
      end

      def macro
        InstanceMacros.new.macro_foobar
      end

      def function
        InstanceMacros.new.call_foobar
      end
    EOF

    assert_equal("foobar", script.function)
    assert_equal("foobar", script.macro)
  end

  def test_unquote
    # TODO fix annotation output and create a duby.anno.Extensions annotation.
    return if self.class.name == 'TestJavacCompiler'

    script, cls = compile(<<-'EOF')
      class UnquoteMacros
        macro def make_attr(name_node, type)
          name = name_node.string_value
          quote do
            def `name`
              @`name`
            end
            def `"#{name}_set"`(`name`:`type`)
              @`name` = `name`
            end
          end
        end

        make_attr :foo, :int
      end

      x = UnquoteMacros.new
      puts x.foo
      x.foo = 3
      puts x.foo
    EOF
    assert_output("0\n3\n") {script.main(nil)}
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

    scripe, cls = compile(<<-EOF)
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
            print 'Static Hello'
          end
        end
      end
    EOF

    output = capture_output do
      cls.hi
    end

    assert_equal('Static Hello', output)
  end

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

  def test_loop_in_ensure
    cls, = compile(<<-EOF)
    begin
      puts "a"
      begin
        puts "b"
        break
      end while false
      puts "c"
    ensure
      puts "ensure"
    end
    EOF

    assert_output("a\nb\nc\nensure\n") { cls.main(nil) }
  end

  def test_return_type
    assert_raise Mirah::Typer::InferenceError do
      compile(<<-EOF)
        class ReturnsA
          def a:int
            :foo
          end
        end
      EOF
    end

    assert_raise Mirah::Typer::InferenceError do
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
    script, cls1, cls2 = compile(<<-EOF)
      abstract class Abstract
        abstract def foo:void; end
        def bar; puts "bar"; end
      end
      class Concrete < Abstract
        def foo; puts :foo; end
      end
    EOF

    assert_output("foo\nbar\n") do
      a = cls2.new
      a.foo
      a.bar
    end
    begin
      cls1.new
      fail "Expected InstantiationException"
    rescue java.lang.InstantiationException
      # expected
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
      
      # package foo.bar {
      #   class PackagedBar
      #     def self.dosomething
      #       "bar"
      #     end
      #   end
      # }
      
      def dosomething
        "foo"
      end
    EOF

    package = script.java_class.name.split('.')[0]
    assert_equal('foo', package)
    assert_equal('foo', script.dosomething)

    # TODO move package to the parser so we can support blocks
    # assert_equal('bar', cls.dosomething)
    # assert_equal("foo.bar.PackagedBar", cls.java_class.name)
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

  def test_macro_hygene
    cls, = compile(<<-EOF)
      macro def doubleIt(arg)
        quote do
          x = `arg`
          x = x + x
          x
        end
      end

      def foo
        x = "1"
        puts doubleIt(x)
        puts x
      end
    EOF

    assert_output("11\n1\n") {cls.foo}
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
          puts "Hello \#{x}"
        end
        begin
          thread.run
          thread.join
        rescue
          puts "Uh Oh!"
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
end
