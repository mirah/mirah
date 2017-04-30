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
require 'test_helper'

class BlocksTest < Test::Unit::TestCase

  def parse_and_type code, name=tmp_script_name
    parse_and_resolve_types name, code
  end

  # this should probably be a core test
  def test_empty_block_parses_and_types_without_error
    assert_nothing_raised do
      parse_and_type(<<-CODE)
        interface Bar do;def run:void;end;end

        class BarOner
          def initialize; end
          def foo(a:Bar)
            1
          end
        end
        BarOner.new.foo do
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

        class NotEmptyAccepter
          def initialize; end
          def foo(a: Bar)
            1
          end
        end
        NotEmptyAccepter.new.foo do
          1
        end
      CODE
    end
  end

  def test_simple_block
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
    assert_run_output("Hello\n", cls)
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
      o.addObserver {|x, a| puts a}
      o.notifyObservers("Hello Observer")
    EOF
    assert_run_output("Hello Observer\n", script)
  end

  def test_closure
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


  def test_int_closure_with_int_as_method_param
    cls, = compile(<<-EOF)
      def run(x:Runnable)
        x.run
      end
      def foo a: int
        run { a += 1 }
        a
      end
    EOF
    assert_equal(2, cls.foo(1))
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
      list.each {|x| puts x }
    EOF

    assert_run_output("a\nABC\nb\nCats\n", cls)
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
         puts c.call
      end
      begin
      foo do
        "an object"
      end
      rescue
        puts "never get here"
      end
    EOF
    assert_run_output("an object\n", cls)
  end

  def test_nesting_with_abstract_class
    pend 'test_nesting_with_abstract_class' do
      cls, main = compile(%q{
      abstract class Nestable
        abstract def foo(n: Nestable):void;end
        def create(n: Nestable):void
           puts "create #{n}"
           n.foo(n)
        end

        def toString:String
           "nestable"
        end
      end

      class Main
        def self.create(b: Nestable):void
          b.foo(b)
        end

        def self.main(args: String[]):void
          create do |x:Nestable|
            puts "outer foo"
            create do |m: Nestable|
              puts "in foo #{m}"
            end
          end
        end
      end
})
      assert_output "outer foo\ncreate nestable\nin foo nestable\n" do
        main.main([])
      end
    end
  end

  def test_use_abstract_inplace
      pend "test_use_abstract_inplace" do
      #with_finest_logging {
      cls, main, parent =  compile(%q{
      abstract class A < P

        def self.empty:A
          create do
            puts "empty"
          end
        end

        def self.create(n: A):void
           puts "create #{n}"
           n.execute
        end

      end

      class Main
        def self.create(b: Nestable = A.empty):void
          b.execute
        end

        def self.main(args: String[]):void
          create
          create { puts "not empty"}
        end
      end

      abstract class P
        abstract def execute:void;end
      end
})
      assert_output "outer foo\ncreate nestable\nin foo nestable\n" do
        main.main([])
      end
    end
  end

  def test_parameter_used_in_block
    cls, = compile(<<-'EOF')
      def r(r:Runnable); r.run; end
      def foo(x: String): void
        r do
          puts "Hello #{x}"
        end
      end

      foo('there')
    EOF
    assert_run_output("Hello there\n", cls)
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
        foo {puts "Hi"}
      end
    EOF
    assert_output("Hi\n") do
      cls.bar
    end
  end

  def test_block_impling_interface_w_multiple_methods
   begin
      parse_and_type(<<-CODE)
        interface RunOrRun2 do
          def run:void;end
          def run2:void;end
        end

        class RunOrRun2Fooer
          def foo(a:RunOrRun2)
            1
          end
        end
        RunOrRun2Fooer.new.foo do
          1
        end
        CODE
    rescue => ex
      assert_match /multiple abstract/i, ex.message 
    else
      fail "No exception raised"
    end
  end

  def test_block_with_missing_params
    cls, = compile(<<-CODE)
        interface Bar do
          def run(a:String):void;end
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
    assert_run_output("hi\n", cls)
  end

  def test_block_with_too_many_params
    exception = assert_raises Mirah::MirahError do
      parse_and_type(<<-CODE)
        interface SingleArgMethod do
          def run(a:String):void;end
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
    assert_equal 'Does not override a method from a supertype.',
                  exception.message
  end

  def test_call_with_block_assigned_to_macro
    cls, = compile(<<-CODE)
        class S
          def initialize(run: Runnable)
            run.run
          end
          def toString
            "1"
          end
        end
        if true
          a = {}
          a["wut"]= b = S.new { puts "hey" }
          puts a
          puts b
        end
      CODE
    assert_run_output("hey\n{wut=1}\n1\n", cls)
  end

  def test_nested_closure_in_closure_doesnt_raise_error
    cls, = compile(<<-CODE)
        interface BarRunner do;def run:void;end;end

        class Nestable
          def foo(a:BarRunner)
            a.run
          end
        end
        Nestable.new.foo do
          puts "first closure"
          Nestable.new.foo do
            puts "second closure"
          end
        end
      CODE
    assert_run_output("first closure\nsecond closure\n", cls)
  end

  def test_nested_closure_with_var_from_outer_closure
    cls, = compile(<<-'CODE')
      interface BarRunner do;def run:void;end;end

      class Nestable
        def foo(a:BarRunner)
          a.run
        end
      end
      Nestable.new.foo do
        c = "closure"
        puts "first #{c}"
        Nestable.new.foo do
          puts "second #{c}"
        end
      end
    CODE
    assert_run_output("first closure\nsecond closure\n", cls)
  end

  def test_nested_closure_with_nested_closed_over_args
    cls, = compile(<<-'CODE')
      interface Jogger do;def jog(pace:int):void;end;end

      class Nestable
        def foo(pace: int, a: Jogger)
          a.jog(pace)
        end
      end
      Nestable.new.foo 10 do |pace|
        puts "first #{pace}"
        Nestable.new.foo 20 do |inner_pace|
          puts "second #{pace} #{inner_pace}"
        end
      end
    CODE
    assert_run_output("first 10\nsecond 10 20\n", cls)
  end

  def test_nested_closure_with_nested_closed_over_args2
    cls, = compile(%q[
      interface Jogger do;def jog(param:int):void;end;end
      
      class Nestable
        def operate(blub: int, a: Jogger):void
          a.jog(blub)
        end
      end
      
      class Bar
        def baz(foo:int):void
          puts "bazstart"
          Nestable.new.operate(10) do |arg1|
            puts "first #{arg1} #{foo}"
            Nestable.new.operate 20 do |inner_pace|
              puts "second #{arg1} #{inner_pace} #{foo}"
            end
            Nestable.new.operate 30 do |inner_pace2|
              puts "third #{arg1} #{inner_pace2}  #{foo}"
            end
          end
        end
      end
      
      Bar.new.baz(4)
    ])
    assert_run_output("bazstart\nfirst 10 4\nsecond 10 20 4\nthird 10 30  4\n", cls)
  end

  def test_two_closures_capture_different_variables
    cls, = compile(%q[
      interface Jogger do;def jog(param:int):void;end;end
      
      class Nestable
        def operate(blub: int, a: Jogger):void
          a.jog(blub)
        end
      end
      
      class Bar
        def baz(foo:int):void
          puts "bazstart"
          bar = 7
          Nestable.new.operate(40) do |arg1|
            puts bar
          end
          Nestable.new.operate(10) do |arg1|
            puts "first #{arg1} #{foo}"
          end
        end
      end
      
      Bar.new.baz(4)
    ])
    assert_run_output("bazstart\n7\nfirst 10 4\n", cls)
  end

  def test_uncastable_block_arg_type_fails
    error = assert_raises Mirah::MirahError do
      compile(<<-EOF)
        import java.io.OutputStream
        def foo x:OutputStream
          x.write byte(1)
        rescue
        end
        foo do |b:String|
          puts "writing"
        end
      EOF
    end
    assert_equal "Cannot cast java.lang.String to int.", error.message
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
    assert_run_output("writing\n", cls)
  end

  def test_block_with_interface_method_with_2_arguments_with_types
    cls, = compile(<<-EOF)
      interface DoubleArgMethod do
        def run(a: String, b: int):void;end
      end

      class ExpectsDoubleArgMethod
        def foo(a:DoubleArgMethod)
          a.run "hello", 1243
        end
      end
      ExpectsDoubleArgMethod.new.foo do |a: String, b: int|
        puts a
        puts b
      end
    EOF
    assert_run_output("hello\n1243\n", cls)
  end

  def test_block_with_interface_method_with_2_arguments_without_types
    cls, = compile(<<-EOF)
      interface DoubleArgMethod2 do
        def run(a: String, b: int):void;end
      end

      class ExpectsDoubleArgMethod2
        def foo(a:DoubleArgMethod2)
          a.run "hello", 1243
        end
      end
      ExpectsDoubleArgMethod2.new.foo do |a, b|
        puts a
        puts b
      end
    EOF
    assert_run_output("hello\n1243\n", cls)
  end

  def test_closures_with_static_imports
    cls, = compile(<<-EOF)
      def foo a:Runnable
        a.run
      end
      foo do
        x = [2,1]
        import static java.util.Collections.*
        sort x
        puts x
      end
    EOF
    assert_run_output("[1, 2]\n", cls)
  end

  def test_closures_support_non_local_return
    pend "nlr doesnt work right now" do
    cls, = compile(<<-EOF)
      class NonLocalMe
        def foo(a: Runnable)
          a.run
          puts "doesn't get here"
        end
      end
      def nlr: String
        NonLocalMe.new.foo { return "NLR!"}
        "nor here either"
      end
      puts nlr
    EOF
    assert_run_output("NLR!\n", cls)
    end
  end

  def test_closures_support_non_local_return_with_primitives
    pend "nlr doesnt work right now" do
    cls, = compile(<<-EOF)
      class NonLocalMe
        def foo(a: Runnable)
          a.run
          puts "doesn't get here"
        end
      end
      def nlr: int
        NonLocalMe.new.foo { return 1234}
        5678
      end
      puts nlr
    EOF
    assert_run_output("1234\n", cls)
    end
  end

  def test_when_non_local_return_types_incompatible_has_error
    error = assert_raises Mirah::MirahError do
      parse_and_type(<<-CODE)
      class NonLocalMe
        def foo(a: Runnable)
          a.run
          puts "doesn't get here"
        end
      end
      def nlr: int
        NonLocalMe.new.foo { return "not an int" }
        5678
      end

      CODE
    end
    pend "differing type signatures for nlr" do
      # could be better, if future knew it was a return type
      assert_equal "Invalid return type java.lang.String, expected int", error.message
    end
  end

  def test_closures_non_local_return_to_a_script
    pend "nlr doesnt work right now" do
    cls, = compile(<<-EOF)
      def foo(a: Runnable)
        a.run
        puts "doesn't get here"
      end
      puts "before"
      foo { return }
      puts "or here"
    EOF
    assert_run_output("before\n", cls)
    end
  end

  def test_closures_non_local_return_defined_in_a_class
    pend "nlr doesnt work right now" do
    cls, = compile(<<-EOF)
      class ClosureInMethodInClass
        def foo(a: Runnable)
          a.run
          puts "doesn't get here"
        end
        def nlr
          puts "before"
          foo { return 1234 }
          puts "or here"
          5678
        end
      end
      puts ClosureInMethodInClass.new.nlr
    EOF
    assert_run_output("before\n1234\n", cls)
    end
  end

  def test_closures_non_local_return_defined_in_a_void_method
    pend "nlr doesnt work right now" do
    cls, = compile(<<-EOF)
      class ClosureInVoidMethodInClass
        def foo(a: Runnable)
          a.run
          puts "doesn't get here"
        end
        def nlr: void
          puts "before"
          foo { return }
          puts "or here"
        end
      end
      ClosureInVoidMethodInClass.new.nlr
    EOF
    assert_run_output("before\n", cls)
    end
  end

  def test_closure_non_local_return_with_multiple_returns
    pend "nlr doesnt work right now" do
    cls, = compile(<<-EOF)
      class NLRMultipleReturnRunner
        def foo(a: Runnable)
          a.run
          puts "doesn't get here"
        end
      end
      def nlr(flag: boolean): String
        NLRMultipleReturnRunner.new.foo { if flag; return "NLR!"; else; return "NLArrrr"; end}
        "nor here either"
      end
      puts nlr true
      puts nlr false
    EOF
    assert_run_output("NLR!\nNLArrrr\n", cls)
    end
  end

  def test_two_nlr_closures_in_the_same_method_in_if
    pend "nlr doesnt work right now" do
    cls, = compile(<<-EOF)
      class NLRTwoClosure
        def foo(a: Runnable)
          a.run
          puts "doesn't get here"
        end
      end
      def nlr(flag: boolean): String
        if flag
          NLRTwoClosure.new.foo { return "NLR!" }
        else
          NLRTwoClosure.new.foo { return "NLArrrr" }
        end
        "nor here either"
      end
      puts nlr true
      puts nlr false
    EOF
    assert_run_output("NLR!\nNLArrrr\n", cls)
    end
  end

  def test_two_nlr_closures_in_the_same_method
    pend "nlr doesnt work right now" do
    # this has a binding generation problem
    cls, = compile(<<-EOF)
      class NonLocalMe2
        def foo(a: Runnable)
          a.run
          puts "may get here"
        end
      end
      def nlr(flag: boolean): String
        NonLocalMe2.new.foo { return "NLR!" if flag }
        NonLocalMe2.new.foo { return "NLArrrr" unless flag }
        "but not here"
      end
      puts nlr true
      puts nlr false
    EOF
    assert_run_output("NLR!\nmay get here\nNLArrrr\n", cls)
    end
  end


  def test_method_returning_init_call_with_closure
    cls, = compile(<<-EOF)
      class InitWithRunnable
        def initialize(a: Runnable)
          a.run
        end
        def finish
          "finish"
        end
      end
      class Huh
        def wut(i: InitWithRunnable)
          puts i.finish
        end
        def regular
          InitWithRunnable.new { puts "Closure!"; nil }
        end
      end
      Huh.new.wut(Huh.new.regular)
    EOF

    assert_run_output("Closure!\nfinish\n", cls)
  end


  def test_closure_with_or
    cls, = compile(<<-EOF)
    def r(run: java.lang.Runnable) run.run; end
    r { puts "a" || "b"}
    EOF

    assert_run_output("a\n", cls)
  end

  def test_closure_with_or_ii
    cls, = compile(<<-EOF)
    interface C; def c(): String;end;end
    def r(cee: C) puts cee.c; end
    r { "a" || "b"}
    EOF

    assert_run_output("a\n", cls)
  end

  def test_two_closures_in_the_same_method
    cls, = compile(<<-EOF)
      def foo(a: Runnable)
        a.run
      end
      def regular: String
        foo { puts "Closure!" }
        foo { puts "We Want it" }
        "finish"
      end
      regular
    EOF
    assert_run_output("Closure!\nWe Want it\n", cls)
  end

  def test_closures_in_a_rescue
    cls, = compile(<<-EOF)
      def foo(a: Runnable)
        a.run
      end
      def regular: String
        begin
          foo { puts "Closure!" }
          raise "wut"
        rescue
          foo { puts "We Want it" }
        end
        "finish"
      end
      regular
    EOF
    assert_run_output("Closure!\nWe Want it\n", cls)
  end

  def test_lambda_with_type_defined_before
    cls, = compile(<<-EOF)
      interface Fooable
        def foo: void; end
      end
      x = lambda(Fooable) { puts "hey you" }
      x.foo
    EOF
    assert_run_output("hey you\n", cls)
  end

  def test_lambda_with_type_defined_later
    cls, = compile(<<-EOF)
      x = lambda(Fooable) { puts "hey you" }
      interface Fooable
        def foo: void; end
      end
      x.foo
    EOF
    assert_run_output("hey you\n", cls)
  end

  def test_closure_with_primitive_array_param
    cls, = compile(<<-EOF)
      interface Byter
        def byteme(bytes: byte[]): void; end
      end
      def r b: Byter
        b.byteme "yay".getBytes
      end
      r {|b| puts String.new(b) }
    EOF
    assert_run_output("yay\n", cls)
  end


  def test_block_syntax_for_anonymous_class_implementing_inner_interface
    cls, = compile('
      import org.foo.InnerInterfaceClass
      
      InnerInterfaceClass.forward("foo") do |param|
        puts param
      end
    ')
    assert_run_output("foo\n", cls)
  end

  def test_block_syntax_for_abstract_class_invoke_self
    omit_if JVMCompiler::JVM_VERSION.to_f < 1.8
    cls, = compile('
      import org.foo.AbstractExecutorJava8

      AbstractExecutorJava8.execute do
        puts "foo"
      end
    ')
    assert_run_output("foo\n", cls)
  end

  def test_lambda_closure
    cls, = compile(<<-EOF)
      def r b: Runnable
        b.run
      end
      msg = "yay"
      l = lambda(Runnable) { puts msg }
      r l
    EOF
    assert_run_output("yay\n", cls)
  end


  def test_binding_in_class_definition_has_right_namespace
    classes = compile(<<-'EOF')
      package test
      class Something
        def create(a: Runnable):void
          a.run
        end
        def with_binding
          loc = 1
          create do
            puts "test #{loc}"
          end
        end
      end
    EOF
    class_names = classes.map(&:java_class).map(&:name)
    pattern = /test\.Something\$.*?Binding\d*/
    assert class_names.find{|c| c.match pattern },
      "generated classes: #{class_names} didn't contain #{pattern}."
  end


  def test_binding_in_script_has_right_namespace
    classes = compile(<<-'EOF', name: 'MyScript')
      def create(a: Runnable):void
        a.run
      end
      def with_binding
        loc = 1
        create do
          puts "test #{loc}"
        end
      end
    EOF
    class_names = classes.map(&:java_class).map(&:name)
    pattern = /MyScriptTopLevel\$.*?Binding\d*/

    assert class_names.find{|c| c.match pattern },
      "generated classes: #{class_names} didn't contain #{pattern}."
  end



  # nested nlr scopes

# works with script as end
  # non-local-return when return type incompat, has sensible error
  # non-local-return when multiple non-local-return blocks in same method
  # non-local-return when multiple non-local-return blocks in same method, in if statment
  # non-local-return when multiple non-local-return block with multiple returns
  #    
end
