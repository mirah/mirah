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

class ConstructorsTest < Test::Unit::TestCase
  def test_constructor
    cls, = compile(
        "class InitializeTest;def initialize;puts 'Constructed';end;end")
    assert_output("Constructed\n") do
      cls.new
    end
  end

  def test_constructor_chaining
    foo, = compile(<<-EOF)
      class Foo5
        def initialize(s:String)
          initialize(s, "foo")
        end

        def initialize(s:String, f:String)
          @s = s
          @f = f
        end

        def f
          @f
        end

        def s
          @s
        end
      end
    EOF

    instance = foo.new("S")
    assert_equal("S", instance.s)
    assert_equal("foo", instance.f)

    instance = foo.new("foo", "bar")
    assert_equal("foo", instance.s)
    assert_equal("bar", instance.f)
  end

  def test_super_constructor
    sc_a, sc_b = compile(<<-EOF)
      class SC_A
        def initialize(a:int)
          puts "A"
        end
      end

      class SC_B < SC_A
        def initialize
          super(0)
          puts "B"
        end
      end
    EOF
    assert_output("A\nB\n") do
      sc_b.new
    end
  end

  def test_super_constructor_inferred_args_like_ruby
    sc_a, sc_b = compile(<<-EOF)
      class SuperCA
        def initialize(a: int)
          puts "A \#{a}"
        end
      end

      class SuperCB < SuperCA
        def initialize a: int
          super
          puts "B \#{a}"
        end
      end
    EOF
    assert_output("A 1\nB 1\n") do
      sc_b.new 1
    end
  end

  def test_when_inferred_args_dont_match_super_has_error
    error = assert_raises Mirah::MirahError do
      compile(<<-EOF)
        class SuperCA
          def initialize(a: int);end
        end

        class SuperCB < SuperCA
          def initialize; super; end
        end
      EOF
    end
    assert_match /Can.*t find.* method (SuperCA\.)?initialize\(\)/, error.message
  end


  def test_when_inferred_args_dont_match_java_super_has_error
    error = assert_raises Mirah::MirahError do
      compile(<<-EOF)
        import java.util.ArrayList
        class SuperArray < ArrayList
          def initialize str: String; super; end
        end
      EOF
    end
    assert_match /Can.*t find( instance)? method (java.util.ArrayList\.)?initialize\(java.lang.String\)/, error.message
  end

  def test_empty_constructor
    foo, = compile(<<-EOF)
      class Foo6
        def initialize; end
      end
    EOF
    foo.new
  end

  def test_inexact_constructor
    # FIXME: this is a stupid test
    cls, = compile(<<-EOF)
      class EmptyEmpty
        def self.empty_empty
          t = Thread.new(Thread.new)
          t.start
          begin
            t.join
          rescue InterruptedException
          end
          puts 'ok'
        end
      end
    EOF
    assert_output("ok\n") do
      cls.empty_empty
    end
  end

  def test_default_constructor
    script, cls = compile(<<-EOF)
      class DefaultConstructable
        def foo
          "foo"
        end
      end

      System.out.print DefaultConstructable.new.foo
    EOF

    assert_run_output("foo", script)
  end
end
