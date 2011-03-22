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

require 'mirah/argument_processor'
require 'mirah/compilation_state'

module Mirah
  module Commands
    class Base
      def initialize
        Mirah::AST.type_factory = Mirah::JVM::Types::TypeFactory.new
        @state = Mirah::CompilationState.new
      end
      
      def execute_base(args)
        Mirah::ArgumentProcessor.process_args(@state, args)
        yield
      rescue Mirah::InternalCompilerError => ice
        Mirah.print_error(ice.message, ice.position) if ice.node
        raise ice
      rescue Mirah::MirahError => ex
        Mirah.print_error(ex.message, ex.position)
        puts ex.backtrace if @state.verbose
      end
      
      def generate_bytes
        generate do |filename, builder|
          filename = "#{@state.destination}#{filename}"
          bytes = builder.generate
          yield filename, builder.class_name, bytes
        end
      end
      
      def generate(&block)
        # collect all ASTs from all files
        puts "Parsing..." unless @state.running?
        parse_files
        
        # enter all ASTs into inference engine
        puts "Inferring types..." unless @state.running?
        infer_asts
        
        # compile each AST in turn
        puts "Compiling..." unless @state.running?
        compile_asts(&block)
        
        puts "Done!" unless @state.running?
      end
      
      def parse_files
        @all_nodes = []
        expand_files.each do |duby_file|
          if duby_file == '-e'
            @filename = '-e'
            next
          elsif @filename == '-e'
            puts "  <inline script>" unless @state.running?
            @all_nodes << parse_source('-e', duby_file)
          else
            puts "  #{duby_file}" unless @state.running?
            @all_nodes << parse_source(duby_file)
          end
          @filename = nil
          exit 1 if @error
        end
      end
      
      def parse_source(*parse_targets)
        @filename = parse_targets.shift
        
        if @filename
          if @filename == '-e'
            @filename = 'DashE'
            src = parse_targets[0]
          else
            src = File.read(@filename)
          end
        else
          print_help
          exit(1)
        end
        begin
          ast = Mirah::AST.parse_ruby(src, @filename)
          # rescue org.jrubyparser.lexer.SyntaxException => ex
          #   Mirah.print_error(ex.message, ex.position)
          #   raise ex if @state.verbose
        end
        @transformer = Mirah::Transform::Transformer.new(@state)
        Java::MirahImpl::Builtin.initialize_builtins(@transformer)
        @transformer.filename = @filename
        ast = @transformer.transform(ast, nil)
        @transformer.errors.each do |ex|
          Mirah.print_error(ex.message, ex.position)
          raise ex.cause || ex if @state.verbose
        end
        @error = @transformer.errors.size > 0
        
        ast
      end
      
      def infer_asts
        typer = Mirah::Typer::JVM.new(@transformer)
        @all_nodes.each {|ast| typer.infer(ast, true) }
        begin
          typer.resolve(false)
        ensure
          puts @all_nodes.inspect if @state.verbose
          
          failed = !typer.errors.empty?
          if failed
            puts "Inference Error:"
            typer.errors.each do |ex|
              if ex.node
                Mirah.print_error(ex.message, ex.position)
              else
                puts ex.message
              end
              puts ex.backtrace if @state.verbose
            end
            exit 1
          end
        end
      end
      
      def compile_asts(&block)
        @all_nodes.each do |ast|
          puts "  #{ast.position.file}" unless @state.running?
          compile_ast(ast, &block)
        end
      end
      
      def compile_ast(ast, &block)
        compiler = @state.compiler_class.new
        ast.compile(compiler, false)
        compiler.generate(&block)
      end
      
      def print_help
        puts "#{$0} [flags] <files or -e SCRIPT>
        -c, --classpath PATH\tAdd PATH to the Java classpath for compilation
        --cd DIR\t\tSwitch to the specified DIR befor compilation
        -d, --dir DIR\t\tUse DIR as the base dir for compilation, packages
        -e CODE\t\tCompile or run the inline script following -e
        \t\t\t  (the class will be named \"DashE\")
        --explicit-packages\tRequire explicit 'package' lines in source
        -h, --help\t\tPrint this help message
        -I DIR\t\tAdd DIR to the Ruby load path before running
        -j, --java\t\tOutput .java source (compile mode only)
        --jvm VERSION\t\tEmit JVM bytecode targeting specified JVM
        \t\t\t  version (1.4, 1.5, 1.6, 1.7)
        -p, --plugin PLUGIN\trequire 'mirah/plugin/PLUGIN' before running
        -v, --version\t\tPrint the version of Mirah to the console
        -V, --verbose\t\tVerbose logging"
        @state.help_printed = true
      end
      
      def print_version
        puts "Mirah v#{Mirah::VERSION}"
        @state.version_printed = true
      end
      
      def expand_files
        expanded = []
        @state.args.each do |filename|
          if File.directory?(filename)
            Dir[File.join(filename, '*')].each do |child|
              if File.directory?(child)
                files << child
              elsif child =~ /\.(duby|mirah)$/
                expanded << child
              end
            end
          else
            expanded << filename
          end
        end
        expanded
      end
    end
  end
end