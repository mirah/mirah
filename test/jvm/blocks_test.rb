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

class BlocksTest < Test::Unit::TestCase

  def parse_and_type code, name=tmp_script_name
    parse_and_resolve_types name, code
  end

  #this should probably be a core test
  def test_empty_block_parses_and_types_without_error
    assert_nothing_raised do
      parse_and_type(<<-CODE)
        interface Bar do;def run:void;end;end

        class Foo
          def initialize; end
          def foo(a:Bar)
            1
          end
        end
        Foo.new.foo do
        end
      CODE
    end
  end

  def test_non_empty_block_parses_and_types_without_error
    assert_nothing_raised do
      parse_and_type(<<-CODE)
        interface Bar
          def run:void; end
        end

        class Foo
          def initialize; end
          def foo(a:Bar)
            1
          end
        end
        Foo.new.foo do
          1
        end
      CODE
    end
  end


  def test_simple_block
    cls, = compile(<<-EOF)
      thread = Thread.new do
        System.out.println "Hello"
      end
      begin
        thread.run
        thread.join
      rescue
        System.out.println "Uh Oh!"
      end
    EOF
    assert_output("Hello\n") do
      cls.main([].to_java :string)
    end
  end

  def test_arg_types_inferred_from_interface
    script, cls = compile(<<-EOF)
      import java.util.Observable
      class MyObservable < Observable
        def initialize
          setChanged
        end
      end

      o = MyObservable.new
      o.addObserver {|x, a| System.out.println a}
      o.notifyObservers("Hello Observer")
    EOF
    assert_output("Hello Observer\n") do
      script.main([].to_java :string)
    end
  end

  def test_closure
    cls, = compile(<<-EOF)
      def foo
        a = "Hello"
        thread = Thread.new do
          System.out.println a
        end
        begin
          a = a + " Closures"
          thread.run
          thread.join
        rescue
          System.out.println "Uh Oh!"
        end
        return
      end
    EOF
    assert_output("Hello Closures\n") do
      cls.foo
    end
  end

  def test_int_closure
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
      list.each {|x| System.out.println x}
    EOF

    assert_output("a\nABC\nb\nCats\n") do
      cls.main(nil)
    end
  end

  def test_block_with_abstract_from_object
    # Comparator interface also defines equals(Object) as abstract,
    # but it can be inherited from Object. We test that here.
    cls, = compile(<<-EOF)
      import java.util.Collections
      import java.util.List
      def sort(l:List)
        Collections.sort(l) do |a:Object, b:Object|
          String(a).compareToIgnoreCase(String(b))
        end
        l
      end
    EOF

    assert_equal(["a", "ABC", "b", "Cats"], cls.sort(["a", "ABC", "Cats", "b"]))
  end

  def test_block_with_no_arguments_and_return_value
    cls, = compile(<<-EOF)
      import java.util.concurrent.Callable
      def foo c:Callable
        # throws Exception
         System.out.println c.call
      end
      begin
      foo do
        "an object"
      end
      rescue
        System.out.println "never get here"
      end
    EOF
    assert_output("an object\n") do
      cls.main(nil)
    end
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

  def test_block_with_mirah_interface
    cls, interface = compile(<<-EOF)
      interface MyProc do
        def call:void; end
      end
      def foo(b:MyProc)
        b.call
      end
      def bar
        foo {System.out.println "Hi"}
      end
    EOF
    assert_output("Hi\n") do
      cls.bar
    end
  end

  def assert_jraise(klass)
    assert_block("#{klass} expected, but none thrown") do
      begin
        yield
      rescue klass
        break
      end
      false
    end
  end

  def test_block_impling_interface_w_multiple_methods
    assert_jraise java.lang.UnsupportedOperationException do
      parse_and_type(<<-CODE)
        interface Bar do
          def run:void;end
          def run2:void;end;
        end

        class Foo
          def foo(a:Bar)
            1
          end
        end
        Foo.new.foo do
          1
        end
        CODE
    end
  end

  def test_block_with_missing_params
    cls, = compile(<<-CODE)
        interface Bar do
          def run(a:string):void;end
        end

        class TakesABar
          def foo(a:Bar)
            a.run("x")
          end
        end
        TakesABar.new.foo do
          puts "hi"
        end
        CODE
    assert_output "hi\n" do
      cls.main(nil)
    end
  end

  def test_block_with_too_many_params
    assert_raises Mirah::MirahError do
      parse_and_type(<<-CODE)
        interface SingleArgMethod do
          def run(a:string):void;end
        end

        class ExpectsSingleArgMethod
          def foo(a:SingleArgMethod)
            1
          end
        end
        ExpectsSingleArgMethod.new.foo do |a, b|
          1
        end
        CODE
      end
  end

  def test_closure_in_closure_doesnt_raise_error
    parse_and_type(<<-CODE)
        interface Bar do;def run:void;end;end

        class Foo
          def foo(a:Bar)
            1
          end
        end
        Foo.new.foo do
          Foo.new.foo do
            1
          end
        end
      CODE
  end

  def test_method_requiring_subclass_of_abstract_class_finds_abstract_method
    cls, = compile(<<-EOF)
      import java.io.OutputStream
      def foo x:OutputStream
        x.write byte(1)
      rescue
      end
      foo do |b:int|
        puts "writing"
      end
    EOF
    assert_output "writing\n" do
      cls.main(nil)
    end
  end
end
