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

require 'base64'
require 'jruby'
require 'mirah/errors'

module Mirah
  module Transform
    class Error < Mirah::MirahError
      attr_reader :position
      def initialize(msg, position, cause=nil)
        position = position.position if position.respond_to? :position
        super(msg, position)
        self.cause = cause
      end
    end

    class Transformer
      begin
        include Java::DubyLangCompiler.Compiler
      rescue NameError
        $CLASSPATH << File.dirname(__FILE__) + '/../../javalib/mirah-bootstrap.jar'
        include Java::DubyLangCompiler.Compiler
      end

      attr_reader :errors, :state
      attr_accessor :filename
      def initialize(state)
        @errors = []
        @tmp_count = 0
        @annotations = []
        @scopes = []
        @extra_body = nil
        @state = state
        @helper = Mirah::AST::TransformHelper.new(self)
      end

      def destination
        @state.destination
      end

      def verbose?
        @state.verbose
      end

      def annotations
        result, @annotations = @annotations, []
        return result
      end

      def add_annotation(annotation)
        @annotations << annotation
        Mirah::AST::Noop.new(annotation.parent, annotation.position)
      end

      def tmp(format="__xform_tmp_%d")
        format % [@tmp_count += 1]
      end

      class JMetaPosition
        attr_accessor :start_line, :end_line, :start_offset, :end_offset, :file
        attr_accessor :startpos, :endpos, :start_col, :end_col

        def initialize(startpos, endpos)
          @startpos = startpos
          @endpos = endpos
          @file = startpos.filename
          @start_line = startpos.line
          @start_offset = startpos.pos
          @start_col = startpos.col
          @end_line = endpos.line
          @end_offset = endpos.pos
          @end_col = endpos.col
        end

        def +(other)
          JMetaPosition.new(@startpos, other.endpos)
        end
      end

      def position(node)
        JMetaPosition.new(node.start_position, node.end_position)
      end

      def camelize(name)
        name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
      end

      def transform(node, parent)
        begin
          top = @extra_body.nil?
          if top
            @extra_body = Mirah::AST::Body.new(nil, position(node))
          end
          method = "transform_#{camelize(node[0])}"
          result = @helper.send method, node, parent
          if top
            body = result.body
            if body.kind_of?(Mirah::AST::Body) && @extra_body.empty?
              @extra_body = body
            else
              result.body = @extra_body
              body.parent = @extra_body
              @extra_body.children.insert(0, body)
            end
          end
          return result
        rescue Error => ex
          @errors << ex
          Mirah::AST::ErrorNode.new(parent, ex)
        rescue Exception => ex
          error = Error.new(ex.message, position(node), ex)
          @errors << error
          Mirah::AST::ErrorNode.new(parent, error)
        end
      end

      def captured?(node)
        depth = node.depth
        scope = @scopes[-1]
        while depth > 0
          depth -= 1
          scope = scope.enclosing_scope
        end
        scope.isCaptured(node.index)
      end

      def eval(src, filename='-', parent=nil, *vars)
        node = Mirah::AST.parse_ruby(src, filename)
        duby_node = transform(node, nil).body
        duby_node.parent = parent
        duby_node
      end

      def dump_ast(node, call=nil)
        encoded = nil
        values = Mirah::AST::Unquote.extract_values do
          encoded = Base64.encode64(Marshal.dump(node))
        end
        scope = call.scope.static_scope if call
        result = Mirah::AST::Array.new(nil, node.position)
        if encoded.size < 65535
          result << Mirah::AST::String.new(result, node.position, encoded)
        else
          strings = Mirah::AST::StringConcat.new(result, node.position)
          result << strings
          while encoded.size >= 65535
            chunk = encoded[0, 65535]
            encoded[0, 65535] = ""
            strings << Mirah::AST::String.new(strings, node.position, chunk)
          end
          strings << Mirah::AST::String.new(strings, node.position, encoded)
        end
        values.each do |value|
          if call
            scoped_value = Mirah::AST::ScopedBody.new(result, value.position)
            scoped_value << value
            scoped_value.static_scope = scope
          else
            scoped_value = value
          end
          result << scoped_value
        end
        return result
      end

      def load_ast(args)
        nodes = args.to_a
        encoded = nodes.shift
        Mirah::AST::Unquote.inject_values(nodes) do
          result = Marshal.load(Base64.decode64(encoded))
          if Mirah::AST::UnquotedValue === result
            result.node
          else
            result
          end
        end
      end

      def __ruby_eval(code, arg)
        self.instance_eval(code)
      end

      def fixnum(value)
        node = eval("1")
        node.literal = value
        node
      end

      def constant(name, array=false)
        node = eval("Foo")
        node.name = name
        node.array = array
        node
      end

      def cast(type, value)
        if value.kind_of?(String)
          value = Mirah::AST::Local.new(@extra_body, @extra_body.position, value)
        end
        fcall = eval("Foo()")
        fcall.name = type
        fcall.parameters = [value]
        fcall
      end

      def string(value)
        node = eval('"Foo"')
        node.literal = value
        node
      end

      def empty_array(type_node, size_node)
        node = eval('int[0]')
        node.type_node = type_node
        node.size = size_node
        node
      end

      def find_class(name)
        AST.type(nil, name, false, false)
      end

      def expand(fvcall, parent)
        result = yield self, fvcall, parent
        unless AST::Node === result
          raise Error.new('Invalid macro result', fvcall.position)
        end
        result
      end

      def append_node(node)
        @extra_body << node
        node
      end

      def define_class(position, name, &block)
        append_node Mirah::AST::ClassDefinition.new(@extra_body, position, name, &block)
      end

      def defineClass(name, superclass=nil)
        define_class(@extra_body.position, name) do |class_def|
          superclass = constant(superclass)
          superclass.parent = class_def
          [superclass, body(class_def)]
        end
      end

      def body(parent=nil)
        parent ||= @extra_body
        Mirah::AST::Body.new(parent, parent.position)
      end

      def define_closure(position, name, enclosing_type)
        target = self
        parent = @extra_body
        enclosing_type = enclosing_type.unmeta
        if enclosing_type.respond_to?(:node) && enclosing_type.node
          parent = target = enclosing_type.node
        end
        target.append_node(Mirah::AST::ClosureDefinition.new(
            parent, position, name, enclosing_type))
      end
    end
  end
  TransformError = Transform::Error

  module AST
    begin
      java_import 'mirah.impl.MirahParser'
    rescue NameError
      $CLASSPATH << File.dirname(__FILE__) + '/../../javalib/mirah-parser.jar'
      java_import 'mirah.impl.MirahParser'
    end
    java_import 'jmeta.ErrorHandler'

    class MirahErrorHandler
      include ErrorHandler
      def warning(messages, positions)
        print "Warning: "
        messages.each_with_index do |message, i|
          jpos = positions[i]
          if jpos
            dpos = Mirah::Transform::Transformer::JMetaPosition.new(jpos, jpos)
            print "#{message} at "
            Mirah.print_error("", dpos)
          else
            print message
          end
        end
      end
    end

    def parse(src, filename='dash_e', raise_errors=false, transformer=nil)
      ast = parse_ruby(src, filename)
      transformer ||= Transform::Transformer.new(Mirah::Util::CompilationState.new)
      transformer.filename = filename
      ast = transformer.transform(ast, nil)
      if raise_errors
        transformer.errors.each do |e|
          raise e.cause || e
        end
      end
      ast
    end
    module_function :parse

    def parse_ruby(src, filename='-')
      raise ArgumentError if src.nil?
      parser = MirahParser.new
      parser.filename = filename
      parser.errorHandler = MirahErrorHandler.new
      begin
        parser.parse(src)
      rescue => ex
        if ex.cause.respond_to? :position
          position = ex.cause.position
          Mirah.print_error(ex.cause.message, position)
        end
        raise ex
      end
    end
    module_function :parse_ruby
  end
end
require 'mirah/transform2'