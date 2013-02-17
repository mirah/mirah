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

class RescueTest < Test::Unit::TestCase

  def test_rescue
    cls, = compile(<<-EOF)
      def foo
        begin
          System.out.println "body"
        rescue
          System.out.println "rescue"
        end
      end
    EOF

    output = capture_output do
      cls.foo
    end
    assert_equal("body\n", output)

    cls, = compile(<<-EOF)
      def foo
        begin
          System.out.println "body"
          raise
        rescue
          System.out.println "rescue"
        end
      end
    EOF

    output = capture_output do
      cls.foo
    end
    assert_equal("body\nrescue\n", output)

    cls, = compile(<<-EOF)
      def foo(a:int)
        begin
          System.out.println "body"
          if a == 0
            raise IllegalArgumentException
          else
            raise
          end
        rescue IllegalArgumentException
          System.out.println "IllegalArgumentException"
        rescue
          System.out.println "rescue"
        end
      end
    EOF

    output = capture_output do
      cls.foo(1)
      cls.foo(0)
    end
    assert_equal("body\nrescue\nbody\nIllegalArgumentException\n", output)

    cls, = compile(<<-EOF)
      def foo(a:int)
        begin
          System.out.println "body"
          if a == 0
            raise IllegalArgumentException
          elsif a == 1
            raise Throwable
          else
            raise
          end
        rescue IllegalArgumentException, Exception
          System.out.println "multi"
        rescue Throwable
          System.out.println "other"
        end
      end
    EOF

    output = capture_output do
      cls.foo(0)
      cls.foo(1)
      cls.foo(2)
    end
    assert_equal("body\nmulti\nbody\nother\nbody\nmulti\n", output)

    cls, = compile(<<-EOF)
      def foo
        begin
          raise "foo"
        rescue => ex
          System.out.println ex.getMessage
        end
      end
    EOF

    output = capture_output do
      cls.foo
    end
    assert_equal("foo\n", output)


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

  def test_empty_rescues
    cls, = compile(<<-EOF)
      begin
      rescue
        nil
      end
    EOF

    cls, = compile(<<-EOF)
      begin
        ""
      rescue
        nil
      end
      nil
    EOF

    cls, = compile(<<-EOF)
      def empty_with_ensure
        begin
          i = 0
          while i < 10
            i += 1
          end
        rescue
        ensure
          System.out.println 'ensuring'
        end
        ""
      end
    EOF
  end


  def test_ensure
    cls, = compile(<<-EOF)
      def foo
        1
      ensure
        System.out.println "Hi"
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
        System.out.println "Hi"
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
          System.out.println "Hi"
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
      System.out.println "a"
      begin
        System.out.println "b"
        break
      end while false
      System.out.println "c"
    ensure
      System.out.println "ensure"
    end
    EOF

    assert_output("a\nb\nc\nensure\n") { cls.main(nil) }
  end
end
