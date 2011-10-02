# TODO refactor this and test_jvm_compiler to use mirah.rb
require 'test_helper'

class TestMacros < Test::Unit::TestCase
  java_import 'java.lang.System'

  def parse(code)
    Mirah::AST.type_factory = Mirah::JVM::Types::TypeFactory.new
    name = "script" + System.nano_time.to_s
    state = Mirah::Util::CompilationState.new
    state.save_extensions = false
    transformer = Mirah::Transform::Transformer.new(state)
    Java::MirahImpl::Builtin.initialize_builtins(transformer)
    ast  = Mirah::AST.parse(code, name, true, transformer)
    typer = Mirah::JVM::Typer.new(transformer)
    ast.infer(typer, true)
    typer.resolve(true)
    ast
  end

  def test_macro_helper
    script = parse(<<-EOF)
      import duby.lang.compiler.Compiler

      def helper(mirah:Compiler)
        name = "foobar"
        mirah.quote { `name` }
      end
    EOF
  end

  def test_self_call_in_unquote
    script = parse(<<-EOF)
      import duby.lang.compiler.Compiler

      def foobar(name:String)
        name
      end

      def helper(mirah:Compiler)
        name = "foobar"
        mirah.quote { `foobar(name)` }
      end
    EOF
  end

end