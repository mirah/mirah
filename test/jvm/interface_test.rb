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

class InterfaceTest < Test::Unit::TestCase
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
    assert_raise_kind_of Mirah::MirahError do
      compile(<<-EOF)
        interface AnInterface
          def a:int; end
        end

        class AImpl implements AnInterface
          def a
            "foo"
          end
        end
      EOF
    end
  end

  def test_interface_implementation_with_non_array_params_doesnt_require_type_information
    interface, a_impl = compile(<<-EOF)
        interface InterfaceWithStrings
          def arr(message:String):int; end
        end

        class StringImpl implements InterfaceWithStrings
          def blah(s:String) s.length ; end
          def arr(message) blah message ; end
        end
      EOF
  end

  def test_interface_implementation_with_array_params_doesnt_requires_type_information
    interface, a_impl = compile(<<-EOF)
      interface InterfaceWithArrays
        def arr(messages:String[]):int; end
      end

      class ImplicitArrImpl implements InterfaceWithArrays
        def blah(s:String[]) s.length ; end
        def arr(messages) blah messages ; end
      end
    EOF
  end


  def test_interface_adds_to_list
    interface, a_impl = compile(<<-EOF)
      interface Stringy
        def act(messages:String):void; end
      end

      class Something implements Stringy
        def initialize; @a = []; end
        def act(messages) @a.add(messages); puts @a ;end
      end
    EOF
  end

  def test_interface_with_default_method_compiles_on_java_8
    omit_if JVMCompiler::JVM_VERSION.to_f < 1.8

    cls, = compile(<<-'EOF', java_version: '1.8')
      interface DefaultMe
        def act(messages:String):void
          puts "#{messages} all the things!"
        end
      end

      class WithDefault implements DefaultMe
      end
      WithDefault.new.act("default")
    EOF
    assert_run_output "default all the things!\n", cls
  end
end
