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

require 'mirah'
require 'mirah/jvm/base'
require 'mirah/jvm/method_lookup'
require 'mirah/jvm/types'
require 'mirah/typer'
require 'mirah/plugin/java'
require 'bitescript'
require 'mirah/jvm/compiler/jvm_bytecode'

module Mirah
  module AST
    class FunctionalCall
      attr_accessor :target
    end
    
    class Super
      attr_accessor :target
    end
  end
end

if __FILE__ == $0
  Mirah::Typer.verbose = true
  Mirah::AST.verbose = true
  Mirah::JVM::Compiler::JVMBytecode.verbose = true
  ast = Mirah::AST.parse(File.read(ARGV[0]))
  
  typer = Mirah::Typer::Simple.new(:script)
  ast.infer(typer)
  typer.resolve(true)
  
  compiler = Mirah::JVM::Compiler::JVMBytecode.new(ARGV[0])
  compiler.compile(ast)
  
  compiler.generate
end
