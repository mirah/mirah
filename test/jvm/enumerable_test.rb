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
          System.out.println x
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
          System.out.println x
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
        a.each {|x| x += 1;System.out.println x; redo if x == 2}
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
        i.downto(1) {|x| System.out.println x }
      end
    EOF

    assert_output("3\n2\n1\n") do
      cls.foo(3)
    end
  end

  def test_upto
    cls, = compile(<<-EOF)
      def foo(i:int)
        i.upto(3) {|x| System.out.println x }
      end
    EOF

    assert_output("1\n2\n3\n") do
      cls.foo(1)
    end
  end

  def test_times
    cls, = compile(<<-EOF)
      def foo(i:int)
        i.times {|x| System.out.println x }
      end
    EOF

    assert_output("0\n1\n2\n") do
      cls.foo(3)
    end

    cls, = compile(<<-EOF)
      def foo(i:int)
        i.times { System.out.println "Hi" }
      end
    EOF

    assert_output("Hi\nHi\nHi\n") do
      cls.foo(3)
    end
  end

  def test_general_loop
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
        [1,2,3].each {|x| System.out.println x}
      end
    EOF
    assert_output("1\n2\n3\n") do
      cls.foo
    end
  end

  def test_each_without_block_arguments
    cls, = compile(<<-EOF)
      def foo
        [1,2,3].each { System.out.println :thrice }
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
        System.out.println [1,2,3].any?
        System.out.println [1,2,3].any? {|x| Integer(x).intValue > 3}
      end
    EOF
    assert_output("true\nfalse\n") do
      cls.foo
    end
  end

  def test_all
    cls, = compile(<<-EOF)
      import java.lang.Integer
      def foo
        System.out.println [1,2,3].all?
        System.out.println [1,2,3].all? {|x| Integer(x).intValue > 3}
      end
    EOF
    assert_output("true\nfalse\n") do
      cls.foo
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
          MyIterator.new(x).each {|y| System.out.println y}
        end
      end
    EOF

    assert_output("Hi\n") do
      cls.test("Hi")
    end
  end
end
