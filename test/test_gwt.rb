$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'duby'
require 'jruby'

class TestGWT < Test::Unit::TestCase
  include Duby::AST
  def test_jsni_no_arg
    new_ast = parse("def_jsni void, _log(), 'hi'").body[0]

    name = new_ast.name
    assert_equal(name,'_log')

    body = new_ast.body.literal
    assert_equal(body,'hi')

    signature = new_ast.signature
    return_type = signature[:return] == Duby::AST::TypeReference.new('void')
    assert_equal(return_type,true)

    has_arguments = new_ast.arguments.args
    assert_equal(has_arguments,nil)
  end

  def test_jsni_one_arg
    new_ast = parse("def_jsni void, _log(message:Object), 'hi'").body[0]

    message_type = new_ast.signature[:message] == Duby::AST::TypeReference.new('Object')
    assert_equal(message_type,true)

    arg_size = new_ast.arguments.args.size
    assert_equal(arg_size,1)
  end

  def test_jsni_two_args
    new_ast = parse("def_jsni void, _log(message:Object,message2:Object), 'hi'").body[0]
    arg_size = new_ast.arguments.args.size
    assert_equal(arg_size,2)
  end
end