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
# TODO refactor this and test_jvm_compiler to use mirah.rb
require 'test_helper'

class MacrosTest < Test::Unit::TestCase
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
