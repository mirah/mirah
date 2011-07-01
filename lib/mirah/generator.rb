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
      scoper = Mirah::Types::Scoper.new
      type_system = Mirah::Types::SimpleTypes.new
      typer = Mirah::Types::Typer::Typer.new(type_system, scoper)
      begin
        nodes.each {|ast| typer.infer(ast, false) }
        process_inference_errors(nodes)
      ensure
        puts nodes.inspect if verbose
      end
    end
  end
end