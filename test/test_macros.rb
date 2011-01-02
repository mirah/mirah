# TODO refactor this and test_jvm_compiler to use mirah.rb

$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'mirah'

class TestMacros < Test::Unit::TestCase
  java_import 'java.lang.System'

  def parse(code)
    Mirah::AST.type_factory = Mirah::JVM::Types::TypeFactory.new
    name = "script" + System.nano_time.to_s
    state = Mirah::CompilationState.new
    state.save_extensions = false
    transformer = Mirah::Transform::Transformer.new(state)
    Java::MirahImpl::Builtin.initialize_builtins(transformer)
    ast  = Mirah::AST.parse(code, name, true, transformer)
    typer = Mirah::Typer::JVM.new(transformer)
    ast.infer(typer)
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

end