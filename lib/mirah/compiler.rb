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

module Mirah
  module Compiler
    class ASTCompiler
      def initialize(compiler_class, logging)
        @compiler_class = compiler_class
        @logging = logging
      end

      attr_accessor :compiler_class, :compiler, :logging

      def compile_asts(nodes, scoper, typer)
        results = []
        puts "Compiling..." if logging
        nodes.each do |ast|
          puts "  #{ast.position.filename}" if logging
          compile_ast(ast, scoper, typer) do |filename, builder|
            results << CompilerResult.new(filename, builder.class_name, builder.generate)
          end
        end
        results
      end

      def compile_ast(ast, scoper, typer, &block)
        @compiler = compiler_class.new(scoper, typer)
        compiler.visit(ast, nil)
        compiler.generate(&block)
      end
    end

    class CompilerResult
      def initialize(filename, classname, bytes)
        @filename, @classname, @bytes = filename, classname, bytes
      end

      attr_accessor :filename, :classname, :bytes
    end
  end
end
