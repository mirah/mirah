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

class TestRescue < Test::Unit::TestCase

  def test_rescue
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
        rescue IllegalArgumentException, RuntimeException
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


    cls, = compile(<<-EOF)
      def foo(x:boolean)
        throws Exception
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
    ex = assert_raise NativeException do
      cls.foo(false)
    end
    assert_equal "java.lang.Exception: !x", ex.message
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
  end
end