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

  def test_static_macro_instance_macro_coexistence_vcall
    script, cls = compile(%q[
      class StaticMacrosWithInstanceMacros
        def foobar
          "foobar"
        end

        macro def macro_foobar
          quote {`@call.target`.foobar}
        end

        def call_foobar_instance
          macro_foobar
        end

        macro def self.macro_foobar
          quote {`@call.target`.new.foobar}
        end

        def self.call_foobar_static
          macro_foobar
        end
      end

      def function
        "#{StaticMacrosWithInstanceMacros.call_foobar_static}\n#{StaticMacrosWithInstanceMacros.new.call_foobar_instance}"
      end
    ])

    assert_equal("foobar\nfoobar", script.function)
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
    pend "This is poor-man's splat-operator. It should be replaced by a proper splat-operator or abolished entirely."
    # This unquote is intended to evaluate to more than just exactly one AST node (that is, 2 nodes in this case) and hence
    # modifies the NodeList higher in the syntax tree, surprisingly.
    # Hence, the intention of this unquote violates the Principle of Least Surprise. 
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
  
  def test_protected_attr_accessor
    script, cls = compile(<<-EOF)
      class ProtectedAttrAccessorTest
        protected attr_accessor foo:int
        
        def selfreflect
          puts self.getClass.getDeclaredMethod("foo").getModifiers
          puts self.getClass.getDeclaredMethod("foo_set",[int.class].toArray(Class[0])).getModifiers
        end
      end

      ProtectedAttrAccessorTest.new.selfreflect
    EOF
    assert_run_output("4\n4\n", script)
  end

  def test_macro_in_abstract_class
    pend
    script, cls = compile(%q{
      interface I1
      end
      
      abstract class C2 implements I1
        macro def self.bar
          quote do
            puts "bar"
          end
        end
      end
    })
    script, _ =compile(%q{
      C2.bar
    })
    assert_run_output("bar\n", script)
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
  
  def test_import_star_with_macro_def
    cls1, cls2 = compile([<<-EOF1, <<-EOF2])
      package org.bar.p1
      import org.bar.p2.*
      macro def foo1; end
      puts MultiPackageImplicitRef.class
    EOF1
      package org.bar.p2
      class MultiPackageImplicitRef; end
    EOF2

    assert_run_output "class org.bar.p2.MultiPackageImplicitRef\n", cls1
  end
  
  def test_explicit_import_of_as_yet_unresolved_type_in_file_with_macro
    cls1, cls2 = compile([<<-EOF1, <<-EOF2])
      package org.bar.p1
      import org.bar.p2.MultiPackageExplicitRef

      macro def foo1; end
      puts MultiPackageExplicitRef.class
    EOF1
      package org.bar.p2
      class MultiPackageExplicitRef; end
    EOF2

    assert_run_output "class org.bar.p2.MultiPackageExplicitRef\n", cls1
  end

  def test_macro_using_imported_unresolved_type_fails_to_compile
    e = assert_raises Mirah::MirahError do
      compile([<<-EOF1, <<-EOF2])
        package org.bar.p1
        import org.bar.p2.UsedInMacro
        
        macro def foo1; puts UsedInMacro; quote {}; end
        foo1
      EOF1
        package org.bar.p2
        class MultiPackageExplicitRef2; end
      EOF2
    end
    assert_equal "UsedInMacro;", e.position
    assert_equal "Cannot find class org.bar.p1.UsedInMacro", e.message
  end

  def test_macro_changes_body_of_class_second_but_last_element
    script, cls = compile(%q{
      class ChangeableClass
        macro def self.method_adding_macro
          node  = @call
          node  = node.parent until node.nil? || node.kind_of?(ClassDefinition) # cannot call enclosing_class(), currently
          klass = ClassDefinition(node)
          
          klass.body.add(quote do
            def another_method
              puts "called"
            end
          end)
          nil
        end
        
        method_adding_macro
        
        def last_body_element
          1
        end
      end
      
      ChangeableClass.new.another_method
    })
    assert_run_output("called\n", script)
  end

  def test_macro_changes_body_of_class_last_element
    script, cls = compile(%q{
      class ChangeableClass
        macro def self.method_adding_macro
          node  = @call
          node  = node.parent until node.nil? || node.kind_of?(ClassDefinition) # cannot call enclosing_class(), currently
          klass = ClassDefinition(node)
          
          klass.body.add(quote do
            def another_method
              puts "called"
            end
          end)
          nil
        end
        
        method_adding_macro
      end
      
      ChangeableClass.new.another_method
    })
    assert_run_output("called\n", script)
  end
  
  def test_macro_in_class_inheriting_from_previously_defined_class_inheriting_from_later_to_be_defined_class
    script, cls = compile(%q{
      interface Bar < Baz
      end
      
      class Foo
        implements Bar
        
        macro def self.generate_foo
          quote do
            def foo
              puts "foo"
            end
          end
        end
        
        generate_foo
      end
      
      interface Baz
      end
      
      Foo.new.foo
    })
    assert_run_output("foo\n", script)
  end
  
  def test_macro_in_class_inheriting_from_previously_defined_class_inheriting_from_later_to_be_defined_class2
    script, cls = compile(%q{
      interface Bar < Baz
      end
      
      class Foo
        implements Bar, Baz
        
        macro def self.generate_foo
          quote do
            def foo
              puts "foo"
            end
          end
        end
        
        generate_foo
      end
      
      interface Baz
      end
      
      Foo.new.foo
    })
    assert_run_output("foo\n", script)
  end
  
  def test_macro_calling_macro_calling_method_definition
    script, cls = compile(%q{
      class Foo
        macro def self.foo(method:MethodDefinition)
          method
        end
        
        macro def self.bar(method:MethodDefinition)
          method
        end
        
        
        def method0
        end
        
        foo def method1
        end
        
        bar def method2
        end
        
        foo bar def method3
          puts "method3"
        end
      end
      
      Foo.new.method3
    })
    assert_run_output("method3\n", script)
  end
  
  def test_gensym_clash
    script, cls = compile(%q{
      result = []
      c = lambda(Runnable) do
        5.times do
        end
      end
      result.each do |r:Runnable|
      end
      
      puts result
    })
    assert_run_output("[]\n", script)
  end

  def test_optional_args_macro
    cls, = compile(<<-CODE)
      class MacroWithBlock
        macro def self._test(block:Block = nil)
          if block
            block.body
          else
            quote { puts "self nil" }
          end
        end

        macro def test(block:Block = nil)
          if block
            block.body
          else
            quote { puts "nil" }
          end
        end

        def self.main(args: String[]):void
          mb = MacroWithBlock.new
          mb.test
          mb.test do
            puts "test"
          end
          _test
          _test do
            puts "self test"
          end
        end
      end
    CODE

    assert_run_output("nil\ntest\nself nil\nself test\n", cls)
  end

  def test_macro_varargs
    cls, = compile(<<-CODE)
      class MacroWithVarargs
        macro def  self.vararg(first:Node, *args:Node)
         list = NodeList.new
         list.add quote do
           puts `first`
         end

         args.each do |arg:Node|
           m = if arg.kind_of? Block
            body = Block(arg).body
            quote do
              puts `body`
            end
            else
            quote do
              puts `arg`
            end
           end
           list.add m
         end
        list
      end

      def self.main(*args:String):void
        vararg 1
        vararg 1, 2
        vararg 1, 2, 3
        vararg 1,2 {"test"}
      end
    end
    CODE

    assert_run_output("1\n1\n2\n1\n2\n3\n1\n2\ntest\n", cls)
  end
end

