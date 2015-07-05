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

class EnumerableTest < Test::Unit::TestCase
  def test_for_in_int_array
    cls, = compile(<<-EOF)
      def foo
        a = int[3]
        count = 0
        for x in a
          count += 1
        end
        count
      end
    EOF
    assert_equal(3, cls.foo)

    cls, = compile(<<-EOF)
      def foo(a:int[])
        count = 0
        for x in a
          count += x
        end
        count
      end
    EOF

    assert_equal(9, cls.foo([2, 3, 4].to_java(:int)))
  end

  def test_each_iterable
    cls, = compile(<<-EOF)
      def foo(a:Iterable)
        a.each do |x|
          puts x
        end
      end
    EOF

    assert_output("1\n2\n3\n") do
      list = java.util.ArrayList.new
      list << "1"
      list << "2"
      list << "3"
      cls.foo(list)
    end
  end

  def test_each_arraylist
    cls, = compile(<<-EOF)
      import java.util.ArrayList
      def foo(a:ArrayList)
        a.each do |x|
          puts x
        end
      end
    EOF

    assert_output("1\n2\n3\n") do
      list = java.util.ArrayList.new
      list << "1"
      list << "2"
      list << "3"
      cls.foo(list)
    end
  end

  def test_each_int_arry
    cls, = compile(<<-EOF)
      def foo(a:int[])
        a.each {|x| x += 1;puts x; redo if x == 2}
      end
    EOF

    assert_output("2\n3\n3\n4\n") do
      cls.foo([1,2,3].to_java(:int))
    end
  end

  def test_all_int_array
    cls, = compile(<<-EOF)
      def foo(a:int[])
        a.all? {|x| x % 2 == 0}
      end
    EOF

    assert_equal(false, cls.foo([2, 3, 4].to_java(:int)))
    assert_equal(true, cls.foo([2, 0, 4].to_java(:int)))
  end

  def test_all_string_array
    cls, = compile(<<-EOF)
      def foo(a:String[])
        a.all?
      end
    EOF

    assert_equal(true, cls.foo(["a", "", "b"].to_java(:string)))
    assert_equal(false, cls.foo(["a", nil, "b"].to_java(:string)))
  end

  def test_downto
    cls, = compile(<<-EOF)
      def foo(i:int)
        i.downto(1) {|x| puts x }
      end
    EOF

    assert_output("3\n2\n1\n") do
      cls.foo(3)
    end
  end

  def test_upto
    cls, = compile(<<-EOF)
      def foo(i:int)
        i.upto(3) {|x| puts x }
      end
    EOF

    assert_output("1\n2\n3\n") do
      cls.foo(1)
    end
  end

  def test_times_with_arg
    cls, = compile(<<-EOF)
      def foo(i:int)
        i.times {|x| puts x }
      end
    EOF

    assert_output("0\n1\n2\n") do
      cls.foo(3)
    end
  end

  def test_times_without_arg
    cls, = compile(<<-EOF)
      def foo(i:int)
        i.times { puts "Hi" }
      end
    EOF

    assert_output("Hi\nHi\nHi\n") do
      cls.foo(3)
    end
  end

  def test_normal_while_loop
    cls, = compile(<<-EOF)
      def foo(x:boolean)
        a = StringBuilder.new
        while x
          a.append "<body>"
        end
        a.toString
      end
    EOF
    assert_equal("", cls.foo(false))
  end

  def test_postfix_while_loop
    cls, = compile(<<-EOF)
      def foo
        a = StringBuilder.new
        begin
          a.append "<body>"
        end while false
        a.toString
      end
    EOF
    assert_equal("<body>", cls.foo)
  end

  def test_general_loop
    cls, = compile(<<-EOF)
      def foo(x:boolean)
        a = StringBuilder.new
        while x
          init {a.append "<init>"}
          pre {a.append "<pre>"}
          post {a.append "<post>"}
          a.append "<body>"
        end
        a.toString
      end
    EOF
    assert_equal("<init>", cls.foo(false))

    cls, = compile(<<-EOF)
      def foo
        a = StringBuilder.new
        begin
          init {a.append "<init>"}
          pre {a.append "<pre>"}
          post {a.append "<post>"}
          a.append "<body>"
        end while false
        a.toString
      end
    EOF
    assert_equal("<init><pre><body><post>", cls.foo)

    cls, = compile(<<-EOF)
      def foo
        a = StringBuilder.new
        begin
          init {a.append "<init>"}
          pre {a.append "<pre>"}
          post {a.append "<post>"}
          a.append "<body>"
          redo if a.length < 20
        end while false
        a.toString
      end
    EOF
    assert_equal( "<init><pre><body><body><post>", cls.foo)

    cls, = compile(<<-EOF)
      def foo
        a = StringBuilder.new
        while a.length < 20
          init {a.append "<init>"}
          pre {a.append "<pre>"}
          post {a.append "<post>"}
          next if a.length < 17
          a.append "<body>"
        end
        a.toString
      end
    EOF
    assert_equal("<init><pre><post><pre><body><post>", cls.foo)
  end

  def test_each
    cls, = compile(<<-EOF)
      def foo
        [1,2,3].each {|x| puts x}
      end
    EOF
    assert_output("1\n2\n3\n") do
      cls.foo
    end
  end

  def test_each_without_block_arguments
    cls, = compile(<<-EOF)
      def foo
        [1,2,3].each { puts :thrice }
      end
    EOF
    assert_output("thrice\nthrice\nthrice\n") do
      cls.foo
    end
  end

  def test_any
    cls, = compile(<<-EOF)
      import java.lang.Integer
      def foo
        puts [1,2,3].any?
        puts [1,2,3].any? {|x| Integer(x).intValue > 3}
      end
    EOF
    assert_output("true\nfalse\n") do
      cls.foo
    end
  end

  def test_all_empty_block_and_not_with_cast
    cls, = compile(<<-EOF)
      import java.lang.Integer
      def foo
        puts [1,2,3].all?
        puts [1,2,3].all? {|x| Integer(x).intValue > 3}
      end
    EOF
    assert_output("true\nfalse\n") do
      cls.foo
    end
  end
  def test_all_with_block_with_no_cast
    cls, = compile(<<-EOF)
      def foo
        puts [1,2,3].all? {|x| x.intValue > 3}
      end
    EOF
    assert_output("false\n") do
      cls.foo
    end
  end

  def test_map_empty_literal
    cls, = compile(<<-EOF)
       puts [].map { 'b' }
    EOF
    assert_run_output("[]\n", cls)
  end

  def test_map_to_different_type
    cls, = compile(<<-EOF)
      puts [1].map { 'a' }
    EOF
    assert_run_output("[a]\n", cls)
  end

  def test_map_identity
    cls, = compile(<<-EOF)
      puts [1,2,3].map {|x| x}
    EOF
    assert_run_output("[1, 2, 3]\n", cls)
  end

  def test_map_with_type_declaration
    cls, = compile(<<-EOF)
      puts [1,2,3].map {|x:Integer| x.intValue + 1}
    EOF
    assert_run_output("[2, 3, 4]\n", cls)
  end

  def test_native_array_map_empty_literal
    cls, = compile(<<-EOF)
      puts int[0].map { 'b' }
    EOF
    assert_run_output("[]\n", cls)
  end

  def test_native_array_map_to_different_type
    cls, = compile(<<-EOF)
    	a = int[1]
    	a[0] = 1
      puts a.map { 'a' }
    EOF
    assert_run_output("[a]\n", cls)
  end

  def test_native_array_map_identity
    cls, = compile(<<-EOF)
    	a = int[3]
    	a[0] = 1
    	a[1] = 2
    	a[2] = 3
      puts a.map {|x| x}
    EOF
    assert_run_output("[1, 2, 3]\n", cls)
  end

  def test_native_array_map_with_type_declaration
    cls, = compile(<<-EOF)
    	a = int[3]
    	a[0] = 1
    	a[1] = 2
    	a[2] = 3
      puts a.map {|x:int| x + 1}
    EOF
    assert_run_output("[2, 3, 4]\n", cls)
  end

  def test_select_identity
    cls, = compile(<<-EOF)
      puts [1,2,3].select {|x| true}
    EOF
    assert_run_output("[1, 2, 3]\n", cls)
  end

  def test_select_odd
    cls, = compile(<<-EOF)
      puts [1,2,3].select {|x| (x.intValue&1)==1}
    EOF
    assert_run_output("[1, 3]\n", cls)
  end

  def test_select_multistatement_block
    cls, = compile(<<-EOF)
      puts ([1,2,3].select do |x|
       v = x.intValue
       v&1==1
      end)
    EOF
    assert_run_output("[1, 3]\n", cls)
  end
  
  def test_join
    cls, = compile(<<-EOF)
      puts [1,23,4].join
    EOF
    assert_run_output("1234\n", cls)
  end

  def test_join_with_separator
    cls, = compile(<<-EOF)
      puts [1,23,4].join ', '
    EOF
    assert_run_output("1, 23, 4\n", cls)
  end

  def test_zip
    cls, = compile(<<-'EOF')
      def bar
        [1,2,3].zip([4]) {|x, y| puts "#{x}, #{y}"}
      end
    EOF
    assert_output("1, 4\n2, null\n3, null\n") do
      cls.bar
    end

    cls, = compile(<<-'EOF')
      def foo
        [1,2,3].zip([4, 5, 6]) do |x:Integer, y:Integer|
          puts "#{x} + #{y} = #{x.intValue + y.intValue}"
        end
      end
    EOF
    assert_output("1 + 4 = 5\n2 + 5 = 7\n3 + 6 = 9\n") do
      cls.foo
    end
  end

  def test_reduce_with_string_array
    cls, = compile(<<-'EOF')
      def foo
        x = ["a", "b", "c"].reduce {|a, b| "#{a}#{b}"}
        puts x
      end
    EOF
    assert_output("abc\n") do
      cls.foo
    end
  end

  def test_reduce_with_multiple_typed_block_parameters
    cls, = compile(<<-'EOF')
      def foo
        puts [1, 2, 3].reduce {|a:Integer, b:Integer| Integer.new(a.intValue + b.intValue)}
      end
    EOF
    assert_output("6\n") do
      cls.foo
    end
  end

  def test_reduce_with_one_typed_block_parameters
    cls, = compile(<<-'EOF')
      def foo
        puts ["a", "b", "c"].reduce {|a:Integer| "#{a}a"}
      end
    EOF
    assert_output("aaa\n") do
      cls.foo
    end
  end

  def test_reduce_with_no_arguments
    cls, = compile(<<-'EOF')
      def foo
        ["a", "b", "c"].reduce {puts "x"}
      end
    EOF
    assert_output("x\nx\n") do
      cls.foo
    end
  end

  def test_reduce_of_single_element_list_does_not_execute_block
   cls, = compile(<<-'EOF')
      def foo
        puts ["a"].reduce { puts "x"}
      end
    EOF
    assert_output("a\n") do
      cls.foo
    end
  end

  def test_reduce_of_empty_list_with_some_variable_name_as_outer_scope_does_not_effect_outer_scope
    cls, = compile(<<-'EOF')
      def foo
        a = "foo"
        [].reduce {|a| "#{a}a"}
        puts a
      end
    EOF
    assert_output("null\n") do
      cls.foo
    end
  end

  def test_reduce_with_int_array
    if compiler_name == 'new'
      cls, = compile(<<-'EOF')
        def baz
          a = int[3]
          a[0] = 1
          a[1] = 2
          a[2] = 4
          puts a.reduce {|x, y| x * y}
        end
      EOF
      assert_output("8\n") do
        cls.baz
      end
    else
      pend 'Generated bad bytecode'
    end
  end

  def test_mirah_iterable
    cls, = compile(<<-EOF)
      import java.util.Iterator
      class MyIterator; implements Iterable, Iterator
        def initialize(x:Object)
          @next = x
        end

        def hasNext
          @next != nil
        end

        def next
          result = @next
          @next = nil
          result
        end

        def iterator
          self
        end

        def remove
          raise UnsupportedOperationException
        end

        def self.test(x:String)
          MyIterator.new(x).each {|y| puts y}
        end
      end
    EOF

    assert_output("Hi\n") do
      cls.test("Hi")
    end
  end
end
