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
      def initialize(config, compiler_class, logging)
        @config = config
        @compiler_class = compiler_class
        @logging = logging
      end

      attr_accessor :compiler_class, :compiler, :logging

      def compile_asts(nodes, scoper, typer)
        results = []
        puts "Compiling..." if logging
        nodes.each do |ast|
          puts "  #{ast.position.source.name}" if logging
          compile_ast(ast, scoper, typer) do |filename, builder|
            if builder.respond_to?(:class_name)
              class_name = builder.class_name
              bytes = builder.generate
            else
              class_name = filename
              bytes = String.from_java_bytes(builder)
              filename = class_name.tr('.', '/') + ".class"
            end
            results << CompilerResult.new(filename, class_name, bytes)
          end
        end
        results
      end

      def compile_ast(ast, scoper, typer, &block)
        @compiler = compiler_class.new(@config, scoper, typer)
        compiler.visit(ast, nil)
        compiler.generate(&block)
      rescue java.lang.UnsupportedOperationException => ex
        raise MirahError.new(ex.message)
      rescue java.lang.Throwable => ex
        ex.cause.printStackTrace if ex.cause
        raise ex
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
