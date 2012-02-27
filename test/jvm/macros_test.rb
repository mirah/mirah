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

class TestMacros < Test::Unit::TestCase
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
  
  
  def test_instance_macro
    # TODO fix annotation output and create a duby.anno.Extensions annotation.
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
      System.out.println x.foo
      x.foo = 3
      System.out.println x.foo
    EOF
    assert_output("0\n3\n") {script.main(nil)}
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
        System.out.println doubleIt(x)
        System.out.println x
      end
    EOF

    assert_output("11\n1\n") {cls.foo}
  end


  def test_add_args_in_macro
    cls, = compile(<<-EOF)
      macro def foo(a)
        import duby.lang.compiler.Node
        quote { bar "1", `Node(a.child_nodes.get(0)).child_nodes`, "2"}
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
      macro def foo(&block)
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
    assert_raises Mirah::InferenceError do
      compile(<<-EOF)
        macro def foo
          quote { System.out.println :z }
        end
        def foo
          :bar
        end
      EOF
    end

  end
end