$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'duby'
require 'jruby'
require 'stringio'

class TestJVMCompiler < Test::Unit::TestCase
  include Duby
  import java.lang.System
  import java.io.PrintStream

  def setup
    @tmp_classes = []
  end

  def teardown
    AST.type_factory = nil
    File.unlink(*@tmp_classes)
  end

  def compile(code)
    File.unlink(*@tmp_classes)
    @tmp_classes.clear
    AST.type_factory = Duby::JVM::Types::TypeFactory.new
    ast = AST.parse(code)
    compiler = Compiler::JVM.new("script" + System.nano_time.to_s)
    typer = Typer::JVM.new(compiler)
    ast.infer(typer)
    typer.resolve(true)
    compiler.compile(ast)
    classes = []
    loader = org.jruby.util.ClassCache::OneShotClassLoader.new(
        JRuby.runtime.jruby_class_loader)
    compiler.generate do |name, builder|
      bytes = builder.generate
      open("#{name}", "w") do |f|
        f << bytes
      end
      cls = loader.define_class(name[0..-7], bytes.to_java_bytes)
      classes << JavaUtilities.get_proxy_class(cls.name)
      @tmp_classes << "#{name}"
    end

    classes
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
    cls, = compile("def foo; a = float[2]; a[0] = 1.0; a[0]; end")
    assert_equal(Float, cls.foo.class)
    assert_equal(1.0, cls.foo)

    cls, = compile("def foo; a = double[2]; a; end")
    assert_equal(Java::double[].java_class, cls.foo.class.java_class)
    assert_equal([0.0,0.0], cls.foo.to_a)
    cls, = compile(<<-EOF)
      def foo
        a = double[2]
        # awaiting implicit F2D
        # a[0] = 1.0
        a[0]
      end
    EOF
    assert_equal(Float, cls.foo.class)
    assert_equal(0.0, cls.foo)
  end

  def test_array_with_dynamic_size
    cls, = compile("def foo(size => :int); a = int[size + 1];end")
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
    cls, = compile("def foo; a = 'a'; b = 'b'; a + b; end")
    assert_equal("ab", cls.foo)
  end

  def test_void_selfcall
    cls, = compile("import 'System', 'java.lang.System'; def foo; System.gc; end; foo")
    assert_nothing_raised {cls.foo}
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
    cls, = compile("import 'java.util.ArrayList'; def foo(a => ArrayList); a.size; end")
    assert_equal 0, cls.foo(java.util.ArrayList.new)
  end

  def test_interface
    cls, = compile("import 'java.util.concurrent.Callable'; def foo(a => Callable); a.call; end")
    result = cls.foo {0}
    assert_equal 0, result
  end

  def test_class_decl
    script, foo = compile("class ClassDeclTest;end")
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

  def test_puts
    cls, = compile("def foo;puts 'Hello World!';end")
    output = capture_output do
      cls.foo
    end
    assert_equal("Hello World!\n", output)
  end

  def test_constructor
    script, cls = compile(
        "class InitializeTest;def initialize;puts 'Constructed';end;end")
    output = capture_output do
      cls.new
    end
    assert_equal("Constructed\n", output)
  end

  def test_method
    # TODO auto generate a constructor
    script, cls = compile(
      "class MethodTest; def initialize; ''; end; def foo; 'foo';end;end")
    instance = cls.new
    assert_equal(cls, instance.class)
    assert_equal('foo', instance.foo)
  end

  def test_unless_fixnum
    cls, = compile(<<-EOF)
      def foo(a => :fixnum)
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
      def foo(a => :float)
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
      def foo(a => :fixnum)
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
      def foo(a => :float)
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
      def foo(a => :boolean)
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
    # cls, = compile("def foo(a => :int); if a < 0; -a; else; a; end; end")
    # assert_equal 1, cls.foo(-1)
    # assert_equal 3, cls.foo(3)
  end

  def test_trailing_conditions
    cls, = compile(<<-EOF)
      def foo(a => :fixnum)
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
  
  def test_loop
    cls, = compile(
        'def foo(a => :fixnum);while a > 0; a -= 1; puts ".";end;end')
    assert_equal('', capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})
    
    cls, = compile(
        'def foo(a => :fixnum);begin;a -= 1; puts ".";end while a > 0;end')
    assert_equal(".\n", capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})
    
    cls, = compile(
        'def foo(a => :fixnum);until a <= 0; a -= 1; puts ".";end;end')
    assert_equal('', capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})
    
    cls, = compile(
        'def foo(a => :fixnum);begin;a -= 1; puts ".";end until a <= 0;end')
    assert_equal(".\n", capture_output{cls.foo(0)})
    assert_equal(".\n", capture_output{cls.foo(1)})
    assert_equal(".\n.\n", capture_output{cls.foo(2)})
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
    script, cls = compile(<<-EOF)
      class FieldTest
        def initialize(a => :fixnum)
          @a = a
        end
        
        def a
          @a
        end
      end
    EOF
    first = cls.new(1)
    assert_equal(1, first.a)

    second = cls.new(2)
    assert_equal(1, first.a)
    assert_equal(2, second.a)
  end
  
  def test_object_intrinsics
    cls, = compile(<<-EOF)
      import 'java.lang.Object'
      def nil(a => :Object)
        a.nil?
      end
      
      def equal(a => Object, b => Object)
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
  
  def test_argument_widening
    cls, = compile(<<-EOF)
      def Byte(a => :byte)
        Short(a)
      end
    
      def Short(a => :short)
        Int(a)
      end
    
      def Int(a => :int)
        Long(a)
      end
    
      def Long(a => :long)
        Float(a)
      end
    
      def Float(a => :float)
        Double(a)
      end
    
      def Double(a => :double)
        a
      end
      EOF

      assert_equal(1.0, cls.Byte(1))
      assert_equal(127.0, cls.Byte(127))
      assert_equal(128.0, cls.Short(128))
      assert_equal(32767.0, cls.Short(32767))
      assert_equal(32768.0, cls.Int(32768))
      assert_equal(2147483648.0, cls.Long(2147483648))
  end
end
