# Copyright (c) 2015 The Mirah project authors. All Rights Reserved.
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

class RescueTest < Test::Unit::TestCase

  def test_rescue_with_import
    cls, = compile(<<-EOF)
      def foo
        begin
          raise "some error"
        rescue Exception => e
          import java.util.Collections
          x = [3, 1, 2]
          Collections.sort x
          x
        end
      end
    EOF

    assert_equal [1, 2, 3], cls.foo.to_a
  end

  def test_rescue_with_no_raise_runs_begin_and_not_rescue
    cls, = compile(<<-EOF)
      def foo
        begin
          puts "body"
        rescue
          puts "rescue"
        end
      end
    EOF

    output = capture_output do
      cls.foo
    end
    assert_equal("body\n", output)
  end

  def test_rescue_with_raise_after_begin_runs_rescue
    cls, = compile(<<-EOF)
      def foo
        begin
          puts "body"
          raise
        rescue
          puts "rescue"
        end
      end
    EOF

    output = capture_output do
      cls.foo
    end
    assert_equal("body\nrescue\n", output)
  end

  def test_rescue_with_type_clause_and_untyped_clause
    cls, = compile(<<-EOF)
      def foo(a:int)
        begin
          puts "body"
          if a == 0
            raise IllegalArgumentException
          else
            raise
          end
        rescue IllegalArgumentException
          puts "IllegalArgumentException"
        rescue
          puts "rescue"
        end
      end
    EOF

    output = capture_output do
      cls.foo(1)
      cls.foo(0)
    end
    assert_equal("body\nrescue\nbody\nIllegalArgumentException\n", output)
  end


  def test_rescue_with_multiple_types_or_throwable
    cls, = compile(<<-EOF)
      def foo(a:int)
        begin
          puts "body"
          if a == 0
            raise IllegalArgumentException
          elsif a == 1
            raise Throwable
          else
            raise
          end
        rescue IllegalArgumentException, Exception
          puts "multi"
        rescue Throwable
          puts "other"
        end
      end
    EOF

    output = capture_output do
      cls.foo(0)
      cls.foo(1)
      cls.foo(2)
    end
    assert_equal("body\nmulti\nbody\nother\nbody\nmulti\n", output)
  end

  def test_rescue_without_type_with_argument
    cls, = compile(<<-EOF)
      def foo
        begin
          raise "foo"
        rescue => ex
          puts ex.getMessage
        end
      end
    EOF

    output = capture_output do
      cls.foo
    end
    assert_equal("foo\n", output)
  end

  def test_implicit_begin_on_method_with_rescue_and_else
    cls, = compile(<<-EOF)
      def foo(x:boolean)
        # throws Exception
        if x
          raise Exception, "x"
        end
      rescue Exception
        "x"
      else
        raise Exception, "!x"
      end
    EOF

    assert_equal "x", cls.foo(true)
    assert_raise_java java.lang.Exception, "!x" do
      cls.foo(false)
    end
  end

  def test_rescue_with_return_types_correctly
    cls, = compile(<<-EOF)
      def foo:long
        begin
          return bar
        rescue Exception => e
          return long(0)
        end
      end

      def bar
        long(1)
      end
    EOF

    assert_equal 1, cls.foo
  end

  def test_rescue_with_return_returns_value
    cls, = compile(<<-EOF)
      def foo:long
        begin
          raise "some error"
        rescue Exception => e
          return long(0)
        end
      end
    EOF

    assert_equal 0, cls.foo
  end

  def test_rescue_with_else_clause_returns_from_else_when_no_exception
    cls, = compile(<<-EOF)
      def foo:long
        begin
          long(0)
        rescue
          long(1)
        else
          long(2)
        end
      end
    EOF

    assert_equal 2, cls.foo
  end

  def test_rescue_with_else_clause_returns_from_rescue_when_exception_raised
    cls, = compile(<<-EOF)
      def foo:long
        begin
          raise "oh, my"
        rescue
          long(1)
        else
          long(2)
        end
      end
    EOF

    assert_equal 1, cls.foo
  end

  def test_empty_rescue_body_compiles
    compile(<<-EOF)
      begin
      rescue
        nil
      end
    EOF
  end

  def test_rescue_thats_not_an_expression_compiles
    compile(<<-EOF)
      begin
        ""
      rescue
        nil
      end
      nil
    EOF
  end

  def test_rescue_containing_while_with_ensure_runs_ensure
    cls, = compile(<<-EOF)
      def empty_with_ensure
        begin
          i = 0
          while i < 10
            i += 1
          end
        rescue
        ensure
          puts 'ensuring'
        end
        ""
      end
    EOF
    assert_output "ensuring\n" do
      cls.empty_with_ensure
    end
  end

  def test_empty_rescue_body_with_else_runs_else
    cls, = compile(<<-EOF)
      begin
      rescue
        nil
      else
        puts "else"
      end
    EOF
    assert_run_output("else\n", cls)
  end

  def test_ensure
    cls, = compile(<<-EOF)
      def foo
        1
      ensure
        puts "Hi"
      end
    EOF
    output = capture_output do
      assert_equal(1, cls.foo)
    end
    assert_equal "Hi\n", output

    cls, = compile(<<-EOF)
      def foo
        return 1
      ensure
        puts "Hi"
      end
    EOF
    output = capture_output do
      assert_equal(1, cls.foo)
    end
    assert_equal "Hi\n", output

    cls, = compile(<<-EOF)
      def foo
        begin
          break
        ensure
          puts "Hi"
        end while false
      end
    EOF
    output = capture_output do
      cls.foo
    end
    assert_equal "Hi\n", output
  end

  def test_loop_in_ensure
    cls, = compile(<<-EOF)
    begin
      puts "a"
      begin
        puts "b"
        break
      end while false
      puts "c"
    ensure
      puts "ensure"
    end
    EOF

    assert_run_output("a\nb\nc\nensure\n", cls)
  end
end
