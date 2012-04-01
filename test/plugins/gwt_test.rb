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

class GWTTest < Test::Unit::TestCase
  include Mirah::AST

  def test_jsni_static
    new_ast = parse("def_jsni void, _log(), 'hi'").body[0]
    # True after JsniMethodDefinition infer is called.
    assert(!new_ast.static?)

    new_ast = parse("def_jsni void, self._log(), 'hi'").body[0]
    assert_equal(new_ast.static?, true)

    new_ast = parse(<<-'S').body[0].body[0]
      class Log
        def_jsni void, _log(), 'hi'
      end
    S
    assert(!new_ast.static?)
  end

  def test_jsni_no_arg
    new_ast = parse("def_jsni void, _log(), 'hi'").body[0]

    name = new_ast.name
    assert_equal(name, '_log')

    body = new_ast.body.literal
    assert_equal(body, 'hi')

    signature = new_ast.signature
    return_type = signature[:return] == Mirah::AST::TypeReference.new('void')
    assert_equal(return_type, true)

    has_arguments = new_ast.arguments.args
    assert_equal(has_arguments, [])
  end

  def test_jsni_one_arg
    new_ast = parse("def_jsni void, _log(message:Object), 'hi'").body[0]

    message_type = new_ast.signature[:message] == Mirah::AST::TypeReference.new('Object')
    assert_equal(message_type, true)

    arg_size = new_ast.arguments.args.size
    assert_equal(arg_size, 1)
  end

  def test_jsni_two_args
    new_ast = parse("def_jsni void, _log(message:Object,message2:Object), 'hi'").body[0]
    arg_size = new_ast.arguments.args.size
    assert_equal(arg_size, 2)
  end
end