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

class TestBlocks < Test::Unit::TestCase

  def setup
    super
    clear_tmp_files
    reset_type_factory
  end
  
  def parse_and_type code, name=tmp_script_name
    parse_and_resolve_types name, code
  end
  
  #this should probably be a core test
  def test_empty_block_parses_and_types_without_error
    assert_nothing_raised do
      parse_and_type(<<-CODE)
        interface Bar do;def run:void;end;end
      
        class Foo
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
        interface Bar do;def run:void;end;end
      
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


  def test_block_impling_interface_w_multiple_methods
    assert_raises Mirah::NodeError do
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

  def test_block_with_no_params_on_interface_with
    assert_raises Mirah::NodeError do
      parse_and_type(<<-CODE)
        interface Bar do
          def run(a:string):void;end
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

  def test_block_with_too_many_params
    assert_raises Mirah::NodeError do
      parse_and_type(<<-CODE)
        interface Bar do
          def run(a:string):void;end
        end
        
        class Foo
          def foo(a:Bar)
            1
          end
        end
        Foo.new.foo do |a, b|
          1
        end
        CODE
      end
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

  def test_block_with_abstract_from_object
    # Comparator interface also defines equals(Object) as abstract,
    # but it can be inherited from Object. We test that here.
    cls, = compile(<<-EOF)
      import java.util.ArrayList
      import java.util.Collections
      list = ArrayList.new(["a", "ABC", "Cats", "b"])
      Collections.sort(list) do |a, b|
        String(a).compareToIgnoreCase(String(b))
      end
      list.each {|x| puts x}
    EOF

    assert_output("a\nABC\nb\nCats\n") do
      cls.main(nil)
    end
  end
  
  def test_block_with_no_arguments_and_return_value
    cls, = compile(<<-EOF)
      import java.util.concurrent.Callable
      def foo c:Callable
        throws Exception
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
    assert_output("an object\n") do
      cls.main(nil)
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
end
