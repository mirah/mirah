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

class MacrosTest < Test::Unit::TestCase
  def test_vcall_macro
    cls, = compile(<<-EOF)
      macro def foo
        mirah::lang::ast::Null.new
      end

      System.out.println(foo)
    EOF

    assert_output("null\n") {cls.main(nil)}
    assert(!cls.respond_to?(:foo))
  end

  def test_import
    cls, = compile(<<-EOF)
      import java.util.LinkedList
      macro def foo
        LinkedList.new
        Node(nil)
      end

      foo
    EOF

    assert_output("") {cls.main(nil)}
    assert(!cls.respond_to?(:foo))
  end

  def test_fcall_macro
    cls, = compile(<<-EOF)
      macro def foo
        mirah::lang::ast::Null.new
      end

      System.out.println(foo())
    EOF

    assert_output("null\n") {cls.main(nil)}
    assert(!cls.respond_to?(:foo))
  end

  def test_quote
    cls, = compile(<<-EOF)
      macro def foo
        quote { nil }
      end

      System.out.println(foo)
    EOF

    assert_output("null\n") {cls.main(nil)}
    assert(!cls.respond_to?(:foo))
  end

  def test_macro_def_with_arg
    cls, = compile(<<-EOF)
      macro def bar(x)
        x
      end

      def foo
        bar("bar")
      end
    EOF

    assert_equal("bar", cls.foo)
    assert(!cls.respond_to?(:bar))
  end


  def test_instance_macro_call
    script, cls = compile(<<-EOF)
      class InstanceMacros
        def foobar
          "foobar"
        end

        macro def macro_foobar
          quote {`@call.target`.foobar}
        end
      end

      def macro
        InstanceMacros.new.macro_foobar
      end
    EOF

    assert_equal("foobar", script.macro)
  end

  def test_instance_macro_vcall
    script, cls = compile(<<-EOF)
      class InstanceMacros2
        def foobar
          "foobar"
        end

        macro def macro_foobar
          quote {`@call.target`.foobar}
        end

        def call_foobar
          macro_foobar
        end
      end

      def function
        InstanceMacros2.new.call_foobar
      end
    EOF

    assert_equal("foobar", script.function)
  end

  def test_unquote_method_definitions_with_main
    script, cls = compile(<<-EOF)
      class UnquoteMacros
        macro def self.make_attr(name_node:Identifier, type:TypeName)
          name = name_node.identifier
          quote do
            def `name`
              @`name`
            end
            def `"#{name}_set"`(`name`: `type`)
              @`name` = `name`
            end
          end
        end

        make_attr :foo, :int
      end

      x = UnquoteMacros.new
      System.out.println x.foo
      x.foo = 3
      System.out.println x.foo
    EOF
    assert_output("0\n3\n") {script.main(nil)}
  end

  def test_macro_hygene
    # TODO hygenic macros?
    return
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
        System.out.println doubleIt(x)
        System.out.println x
      end
    EOF

    assert_output("11\n1\n") {cls.foo}
  end

  def test_gensym
    # TODO hygenic macros?
    return
    cls, = compile(<<-EOF)
      macro def doubleIt(arg)
        x = gensym
        quote do
          `x` = `arg`
          `x` = `x` + `x`
          `x`
        end
      end

      def foo
        x = 1
        System.out.println doubleIt(x)
        System.out.println x
      end
    EOF

    assert_output("2\n1\n") {cls.foo}
  end

  def test_add_args_in_macro
    cls, = compile(<<-EOF)
      macro def foo(a:Array)
        quote { bar "1", `a.values`, "2"}
      end

      def bar(a:String, b:String, c:String, d:String)
        System.out.println "\#{a} \#{b} \#{c} \#{d}"
      end

      foo(["a", "b"])
    EOF

    assert_output("1 a b 2\n") do
      cls.main(nil)
    end
  end

  def test_block_parameter_uses_outer_scope
    cls, = compile(<<-EOF)
      macro def foo(block:Block)
        quote { z = `block.body`; System.out.println z }
      end
      apple = 1
      foo do
        apple + 2
      end
    EOF

    assert_output("3\n") do
      cls.main(nil)
    end
  end

  def test_method_def_after_macro_def_with_same_name_raises_error
    assert_raises Mirah::MirahError do
      compile(<<-EOF)
        macro def self.foo
          quote { System.out.println :z }
        end
        def foo
          :bar
        end
        foo
      EOF
    end
  end

  def test_macro_def_unquote_named_method_without_main
    cls, = compile <<-EOF
      class FooHaver
        macro def self.null_method(name)
          quote {
            def `name`
            end
          }
        end
        null_method :testing
      end
    EOF
    assert_equal nil, cls.new.testing
  end
  
  def test_attr_accessor
    script, cls = compile(<<-EOF)
      class AttrAccessorTest
        attr_accessor foo: int
      end

      x = AttrAccessorTest.new
      System.out.println x.foo
      x.foo = 3
      System.out.println x.foo
    EOF
    assert_output("0\n3\n") {script.main(nil)}
  end

  def test_separate_compilation
    compile(<<-CODE)
      class InlineOneSayer
        macro def say_one
          quote do
            puts "one"
          end
        end
      end
    CODE
    script, _ =compile(<<-CODE)
      InlineOneSayer.new.say_one
    CODE
    assert_output("one\n") {script.main(nil)}
  end
end
