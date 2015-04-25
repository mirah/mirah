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
  #TODO perhaps one of these should be an error
  def test_block_args_no_pipes_macro
    cls, = compile(<<-EOF)
      macro def foo(list: Node, block: Block)
        quote do
          `list`.each do `block.arguments`
            puts 1
            `block.body`
          end
        end
      end

      foo [2,3] {|x| puts x }
    EOF

    assert_run_output("1\n2\n1\n3\n", cls)
  end

  def test_block_args_with_pipes_macro
    cls, = compile(<<-EOF)
      macro def foo(list: Node, block: Block)
        quote do
          `list`.each do |`block.arguments`|
            puts 1
            `block.body`
          end
        end
      end

      foo [2,3] {|x| puts x }
    EOF

    assert_run_output("1\n2\n1\n3\n", cls)
  end


  def test_vcall_macro
    cls, = compile(<<-EOF)
      macro def foo
        mirah::lang::ast::Null.new
      end

      puts(Object(foo))
    EOF

    assert_run_output("null\n", cls)
    assert(!cls.respond_to?(:foo))
  end

  def test_imported_constants_available_in_macros
    cls, = compile(<<-EOF)
      import java.util.LinkedList
      macro def foo
        LinkedList.new
        Node(nil)
      end

      foo
    EOF

    assert_run_output("", cls)
    assert(!cls.respond_to?(:foo))
  end

  def test_fcall_macro
    cls, = compile(<<-EOF)
      macro def foo
        mirah::lang::ast::Null.new
      end

      puts(Object(foo()))
    EOF

    assert_run_output("null\n", cls)
    assert(!cls.respond_to?(:foo))
  end

  def test_quote
    cls, = compile(<<-EOF)
      macro def foo
        quote { nil }
      end

      puts(Object(foo))
    EOF

    assert_run_output("null\n", cls)
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


  def test_static_macro_call
    script, cls = compile(<<-EOF)
      class StaticMacros
        def self.foobar
          "foobar"
        end

        macro def self.macro_foobar
          quote {`@call.target`.foobar}
        end
      end

      def macro
        StaticMacros.macro_foobar
      end
    EOF

    assert_equal("foobar", script.macro)
  end

  def test_static_macro_vcall
    script, cls = compile(<<-EOF)
      class StaticMacros2
        def foobar
          "foobar"
        end

        macro def self.macro_foobar
          quote {`@call.target`.new.foobar}
        end

        def self.call_foobar
          macro_foobar
        end
      end

      def function
        StaticMacros2.call_foobar
      end
    EOF

    assert_equal("foobar", script.function)
  end


  def test_unquote_method_definitions_with_main
    script, cls = compile(<<-'EOF')
      class UnquoteMacros
        macro def self.make_attr(name_node:Identifier, type:TypeName)
          name = name_node.identifier
          quote do
            def `name`
              @`name`
            end
            def `"#{name}_set"`(`name`: `type`)
              @`name` = `name` # silly parsing `
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

    assert_run_output("0\n3\n", script)
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
        puts doubleIt(x)
        puts x
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
        puts doubleIt(x)
        puts x
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
        puts "\#{a} \#{b} \#{c} \#{d}"
      end

      foo(["a", "b"])
    EOF

    assert_run_output("1 a b 2\n", cls)
  end

  def test_block_parameter_uses_outer_scope
    cls, = compile(<<-EOF)
      macro def foo(block:Block)
        quote { z = `block.body`; puts z }
      end
      apple = 1
      foo do
        apple + 2
      end
    EOF

    assert_run_output("3\n", cls)
  end


  def test_block_parameter
    cls, = compile(<<-EOF)
      macro def foo(&block)
        block.body
      end
      foo do
        puts :hi
      end
    EOF

    assert_run_output("hi\n", cls)
  end

  def test_method_def_after_macro_def_with_same_name_raises_error
    assert_raises Mirah::MirahError do
      compile(<<-EOF)
        macro def self.foo
          quote { puts :z }
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
      puts x.foo
      x.foo = 3
      puts x.foo
    EOF
    assert_run_output("0\n3\n", script)
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
    assert_run_output("one\n", script)
  end

  def test_separate_compilation_different_macro_dest
    compile(<<-CODE, separate_macro_dest: true)
      class InlineTwoSayer
        macro def say_two
          quote do
            puts "two"
          end
        end
      end
    CODE
    script, _ =compile(<<-CODE, separate_macro_dest: true)
      InlineTwoSayer.new.say_two
    CODE
    assert_run_output("two\n", script)
  end
  
  def test_multi_package_compilation_implicit_class_reference
    compile([%q[
      package org.bar.p1
      
      # import org.bar.p2.Class2
      import org.bar.p2.*
      
      class Class1
        macro def foo1
        end
      
        class << self
          def something
            1
          end
          def return_class2
            Class2.something
          end
        end
      end
    ],%q[
      package org.bar.p2
      
      # import org.bar.p1.Class1
      import org.bar.p1.*
      
      class Class2
        macro def foo2
        end
        
        class << self
          def something
            1
          end
          def return_class1
            Class1.something
          end
        end
      end
    ]])
  end
  
  def test_multi_package_compilation_explicit_class_reference
    compile([%q[
      package org.bar.p1
      
      import org.bar.p2.Class2
      # import org.bar.p2.*
      
      class Class1
        macro def foo1
        end
      
        class << self
          def something
            1
          end
          def return_class2
            Class2.something
          end
        end
      end
    ],%q[
      package org.bar.p2
      
      import org.bar.p1.Class1
      # import org.bar.p1.*
      
      class Class2
        macro def foo2
        end
        
        class << self
          def something
            1
          end
          def return_class1
            Class1.something
          end
        end
      end
    ]])
  end
end
