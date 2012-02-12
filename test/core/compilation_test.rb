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

class TestCompilation < Test::Unit::TestCase
  include Mirah

  class MockCompiler
    attr_accessor :calls

    def initialize
      @calls = []
    end
    def compile(ast)
      ast.compile(self, true)
    end

    def line(num)
      # ignore newlines
    end

    def method_missing(sym, *args, &block)
      calls << [sym, *args]
      block.call if block
    end
  end

  class ClassComparison
    def initialize(klass)
      @class = klass
    end

    def ==(other)
      other.kind_of?(@class)
    end
  end

  def a(klass)
    ClassComparison.new(klass)
  end

  def setup
    @compiler = MockCompiler.new
  end

  def test_fixnum
    new_ast = AST.parse("1").body[0]

    new_ast.compile(@compiler, true)

    assert_equal([[:fixnum, nil, 1]], @compiler.calls)
  end

  def test_string
    new_ast = AST.parse("'foo'").body[0]

    new_ast.compile(@compiler, true)

    assert_equal([[:string, "foo"]], @compiler.calls)
  end

  def test_float
    new_ast = AST.parse("1.0").body[0]

    new_ast.compile(@compiler, true)

    assert_equal([[:float, nil, 1.0]], @compiler.calls)
  end

  def test_boolean
    new_ast = AST.parse("true").body[0]

    new_ast.compile(@compiler, true)

    assert_equal([[:boolean, true]], @compiler.calls)
  end

  def test_local
    new_ast = AST.parse("a = 1").body[0]

    new_ast.compile(@compiler, true)

    assert_equal([[:local_assign, a(Mirah::AST::StaticScope), "a", nil, true, AST.fixnum(nil, nil, 1)]], @compiler.calls)
  end

  def test_local_typed
    new_ast = AST.parse("a = 1").body[0]
    typer = Typer::Simple.new(:bar)
    new_ast.infer(typer, true)
    new_ast.compile(@compiler, true)

    assert_equal([[:local_assign, a(Mirah::AST::StaticScope), "a", AST.type(nil, :fixnum), true, AST.fixnum(nil, nil, 1)]], @compiler.calls)
  end

  def test_return
    new_ast = AST.parse("return 1").body[0]
    new_ast.compile(@compiler, true)

    assert_equal([[:return, new_ast]], @compiler.calls)
  end

  def test_empty_array
    new_ast = AST.parse("int[5]").body[0]
    new_ast.compile(@compiler, true)

    assert_equal(1, @compiler.calls.size)
    size = @compiler.calls[0].pop
    assert_equal([[:empty_array, nil]], @compiler.calls)
    assert_equal(5, size.literal)
  end
  
  def test_empty_literal_array
    new_ast = AST.parse("[]").body[0]
    new_ast.compile(@compiler, true)

    assert_equal([:array, a(Mirah::AST::Array), true], @compiler.calls.first)
  end
end