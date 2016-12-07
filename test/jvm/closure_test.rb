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

class ClosureTest < Test::Unit::TestCase

  def test_interface_defined_after_used
    cls, = compile(%q{
      class FooTest1
        def self.main(argv:String[]):void
          FooB.new.action do
            puts "executed foo1"
          end
        end
      end
      
      class FooB
        def action(foo_param:Foo_Interface):void
          foo_param.anymethod
        end
      end 
      
      interface Foo_Interface
        def anymethod():void; end
      end
      
      class FooTest2
        def self.main(argv:String[]):void
          FooB.new.action do
            puts "executed foo2"
          end
        end
      end
      FooTest2.main(String[0])
      FooTest1.main(String[0])
    })
    assert_run_output("executed foo2\nexecuted foo1\n", cls)
  end
  
  def test_super_is_not_synthesized_when_not_necessary
    cls, = compile(%q{
      class Bar
        def initialize(val:int)
          puts "bar"
        end
      end
      
      class Foo < Bar
        attr_accessor baz:String
        
        def initialize(val:int)
          super
          foo = 5
          puts "foo"
          perform do
            puts foo
          end
        end
        
        def perform(runnable:Runnable)
          runnable.run
        end
      end
      Foo.new(3)
    })
    assert_run_output("bar\nfoo\n5\n", cls)
  end

  def test_lambda_and_other_closures_coexist
    cls, = compile(%q[
      class Foo
      
        def anymethod()
          foo = 5
          perform do
            puts "1: #{foo}"
          end
          a = lambda(Runnable) do
            puts "2: #{foo}"
          end
          perform(a)
        end
        
        def perform(runnable:Runnable)
          runnable.run
        end
      end
      Foo.new.anymethod
    ])
    assert_run_output("1: 5\n2: 5\n", cls)
  end

  def test_doubly_nested_lambda
    cls, = compile(%q[
      class Foo
        abstract def test(param:String); end
      end
      
      class Bar < Foo
        def test(param)
          y = 5
          x = lambda(Runnable) do
            puts "so: #{param}"
            z = lambda(Runnable) do
              puts "hey you #{y}"
            end
            z.run
          end
          x.run
        end
      end
      
      Bar.new.test("bar")
    ])
    assert_run_output("so: bar\nhey you 5\n", cls)
  end

  def test_direct_invoke_on_lambda
    cls, = compile(%q[
      lambda(Runnable) do
        puts "abc"
      end.run
    ])
    assert_run_output("abc\n", cls)
  end

  def test_lambda_contains_methods
    cls, = compile(%q[
      foo = 3
      
      lambda(Runnable) do
        def run
          puts foo
        end
      end.run
    ])
    assert_run_output("3\n", cls)
  end
  
  def test_closure_over_array_parameter
    cls, = compile(%q{
      def bar(param:byte[])
        runnable = lambda(Runnable) do
          puts param[0]
        end
        
        runnable.run
      end
      
      bar(byte[1])
    })
    assert_run_output("0\n", cls)
  end
  
  def test_closure_with_typed_parameter
    cls, = compile(%q{
      class Bar
      end
      
      interface Foo
        def action(bar:Bar); end
      end
      
      class FooCaller
      
        def with_foo(foo:Foo):void
          foo.action(Bar.new)
        end
      
        def call_with_foo
          with_foo do |bar:Bar|
            puts "Closure called."
          end
        end
      end
      
      FooCaller.new.call_with_foo
    })
    assert_run_output("Closure called.\n", cls)
  end

  def test_deep_nested_runnable_with_binding
    cls, = compile(%q{
         class TestBuilder
           def self.create(b: Runnable):void
             b.run()
           end

           def self.main(args:String[]):void
             level_0 = "level_0"
             b = create do
               level_1="level_1"
               TestBuilder.create do
                 level_2="level_2"
                 TestBuilder.create do
                   level_3="level_3"
                   puts "#{level_0} #{level_1} #{level_2} #{level_3}"
                  end
                 TestBuilder.create do
                   level_2="level_2_3"
                   puts "#{level_0} #{level_1} #{level_2}"
                 end
                 puts "#{level_0} #{level_1} #{level_2}"
               end
             end
           end
         end

         TestBuilder.main(String[0])
    })
    assert_run_output("level_0 level_1 level_2 level_3\nlevel_0 level_1 level_2_3\nlevel_0 level_1 level_2_3\n", cls)
  end
  
  def test_closure_with_assignment_in_rescue
    cls, = compile(%q{
      foo = nil
      t = Thread.new do
        begin
          raise Exception
        rescue => e
          foo = Integer.new(3)
        end
      end
      t.start
      t.join
      puts foo
    })
    assert_run_output("3\n", cls)
  end

  def test_closing_over_static_method
    cls, = compile(%q{
      def foo
        puts 'yay foo'
      end
      lambda(Runnable) { foo }.run
    })
    assert_run_output("yay foo\n", cls)
  end

  def test_closing_over_instance_method
    cls, = compile(%q{
      class InstanceMethodCarrier
        def foo
          puts 'yay foo'
        end
        def bar
          lambda(Runnable) { foo }.run
        end
      end
      InstanceMethodCarrier.new.bar
    })
    assert_run_output("yay foo\n", cls)
  end

  def test_closing_over_field
    cls, = compile(%q{
      class Bar
        def bar: void
          @foo = 'yay foo'
          lambda(Runnable) { puts @foo }.run
        end
      end
      Bar.new.bar
    })
    assert_run_output("yay foo\n", cls)
  end

  def test_closing_over_self
    cls, = compile(%q{
      class SelfConscious
        def bar
          lambda(Runnable) { puts self }.run
        end
        def toString
          "SelfConscious"
        end
      end
      SelfConscious.new.bar
    })

    assert_run_output("SelfConscious\n", cls)
  end

  def test_closing_over_self_call
    cls, = compile(%q{
      class SelfConscious
        def bar
          lambda(Runnable) { puts self.toString }.run
        end
        def toString
          "SelfConscious"
        end
      end
      SelfConscious.new.bar
    })

    assert_run_output("SelfConscious\n", cls)
  end

  def test_close_over_super_types_method
    cls, = compile(%q{
      class SClass
        def foo
          puts 'yay foo'
        end
      end
      class SubClass < SClass
        def bar
          lambda(Runnable) { foo }.run
        end
      end
      SubClass.new.bar
    })
    assert_run_output("yay foo\n", cls)
  end
  # closure type method called
  # closed over method shadows closure type method
end

