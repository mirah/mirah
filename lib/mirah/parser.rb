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
require 'mirah/transform'
require 'java'

module Mirah
  class Parser
    include Mirah::Util::ProcessErrors

    def initialize(state, typer, logging)
      @transformer = Mirah::Transform::Transformer.new(state, typer)
      #Java::MirahImpl::Builtin.initialize_builtins(@transformer)
      @logging = logging
      @verbose = state.verbose
    end

    attr_accessor :transformer, :logging

    def parse_from_args(files_or_scripts)
      nodes = []
      inline = false
      puts "Parsing..." if logging
      expand_files(files_or_scripts).each do |script|
        if script == '-e'
          inline = true
          next
        elsif inline
          nodes << parse_inline(script)
          break
        else
          nodes << parse_file(script)
        end
      end
      raise 'nothing to parse? ' + files_or_scripts.inspect unless nodes.length > 0
      nodes = nodes.compact
      if @verbose
        nodes.each {|node| puts format_ast(node)}
      end
      nodes
    end

    def parse_inline(source)
      puts "  <inline script>" if logging
      parse_and_transform('DashE', source)
    end

    def parse_file(filename)
      puts "  #{filename}" if logging
      parse_and_transform(filename, File.read(filename))
    end

    def parse_and_transform(filename, src)
      Mirah::AST.parse_ruby(transformer, src, filename)
    end

    def format_ast(ast)
      AstPrinter.new.scan(ast, ast)
    end

    def expand_files(files_or_scripts)
      expanded = []
      files_or_scripts.each do |filename|
        if File.directory?(filename)
          Dir[File.join(filename, '*')].each do |child|
            if File.directory?(child)
              files_or_scripts << child
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

    class AstPrinter < NodeScanner
      java_import "mirah.lang.ast.Node"
      def initialize
        @out = ""
        @indent = 0
        @newline = true
      end
      def puts(*args)
        print(*args)
        @newline = true
        @out << "\n"
      end
      def print(*args)
        @out << (" " * @indent) if @newline
        args.each {|arg| @out << arg}
        @newline = false
        @out
      end
      def indent
        @indent += 2
      end
      def dedent
        @indent -= 2
      end
      def enterNullChild(obj)
        puts("nil")
      end
      
      def startNode(node)
        print("[#{node.java_class.simple_name}")
        indent
      end
        
      def enterDefault(node, arg)
        startNode(node)
        puts
        true
      end
      
      def exitDefault(node, arg)
        dedent
        if @out[-2,2] =~ /^[\[\]"]\n/
          @out[-1,0] = "]"
          @out
        else
          no_children = @out.rindex(/[\]\n]/, -2) < @out.rindex("[")
          if no_children
            @out[-1,0] = "]"
          else
            puts("]")
          end
        end
      end
      
      %w(Boolean Fixnum Float CharLiteral).each do |name|
        eval(<<-EOF)
          def enter#{name}(node, arg)
            startNode(node)
            print(" ", node.value.to_s)
            true
          end
        EOF
      end
      
      def enterSimpleString(node, arg)
        first_child = @out.rindex(/[\]\n]/, -2) < @out.rindex("[")
        if first_child
          @newline = false
          @out[-1,1] = " "
        end
        print '"', node.value
        true
      end
      
      def exitSimpleString(node, arg)
        puts '"'
      end
      
      def enterTypeRefImpl(node, arg)
        startNode(node)
        print " #{node.name}"
        print " array" if node.isArray
        print " static" if node.isStatic
        true
      end

      def enterNodeList(node, arg)
        puts "["
        indent
        true
      end

      def enterBlockArgument(node, arg)
        enterDefault(node, arg)
        puts "optional" if node.optional
        true
      end

      def enterLoop(node, arg)
        enterDefault(node, arg)
        puts "skipFirstCheck" if node.skipFirstCheck
        puts "negative" if node.negative
        true
      end

      def exitFieldAccess(node, arg)
        puts "static" if node.isStatic
        exitDefault(node, arg)
      end
      alias exitFieldAssign exitFieldAccess

      def enterUnquote(node, arg)
        enterDefault(node, arg)
        object = node.object
        if object
          if object.kind_of?(Node)
            scan(object, arg)
          else
            str = if node.object.respond_to?(:toString)
              node.object.toString
            else
              node.object.inspect
            end
            puts "<", str, ">"
          end
        end
        object.nil?
      end
    end
  end
end