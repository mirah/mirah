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
require 'mirah/util/process_errors'

module Mirah
  class Generator
    include Mirah::Util::ProcessErrors
    def initialize(state, compiler_class, logging, verbose)
      @parser = Mirah::Parser.new(state, logging)
      @compiler = Mirah::Compiler::ASTCompiler.new(compiler_class, logging)
      @logging = logging
      @verbose = verbose
    end
    
    attr_accessor :parser, :compiler, :logging, :verbose
      
    def generate(arguments)
      # collect all ASTs from all files
      top_nodes = parser.parse_from_args(arguments)
      
      # enter all ASTs into inference engine
      puts "Inferring types..." if logging
      infer_asts(top_nodes)
      
      # compile each AST in turn
      compiler_results = compiler.compile_asts(top_nodes, parser.transformer)
      
      puts "Done!" if logging
      
      compiler_results
    end
      
    def infer_asts(nodes)
      typer = Mirah::JVM::Typer.new(parser.transformer)
      nodes.each {|ast| typer.infer(ast, true) }
      begin
        typer.resolve(false)
      ensure
        puts nodes.inspect if verbose
        
        failed = !typer.errors.empty?
        if failed
          puts "Inference Error:"
          process_errors(typer.errors)
        end
      end
    end
  end
end