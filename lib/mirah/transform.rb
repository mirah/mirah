require 'base64'
require 'jruby'

module Duby
  module Transform
    class Error < StandardError
      attr_reader :position, :cause
      def initialize(msg, position, cause=nil)
        super(msg)
        @position = position
        @position = position.position if position.respond_to? :position
        @cause = cause
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
        @helper = Duby::AST::TransformHelper.new(self)
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
        Duby::AST::Noop.new(annotation.parent, annotation.position)
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
            @extra_body = Duby::AST::Body.new(nil, position(node))
          end
          method = "transform_#{camelize(node[0])}"
          result = @helper.send method, node, parent
          if top
            body = result.body
            if body.kind_of?(Duby::AST::Body) && @extra_body.empty?
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
          Duby::AST::ErrorNode.new(parent, ex)
        rescue Exception => ex
          error = Error.new(ex.message, position(node), ex)
          @errors << error
          Duby::AST::ErrorNode.new(parent, error)
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
        node = Duby::AST.parse_ruby(src, filename)
        duby_node = transform(node, nil).body
        duby_node.parent = parent
        duby_node
      end

      def dump_ast(node)
        encoded = nil
        values = Duby::AST::Unquote.extract_values do
          encoded = Base64.encode64(Marshal.dump(node))
        end
        result = Duby::AST::Array.new(nil, node.position)
        result << Duby::AST::String.new(result, node.position, encoded)
        values.each {|value| result << value}
        return result
      end

      def load_ast(args)
        nodes = args.to_a
        encoded = nodes.shift
        Duby::AST::Unquote.inject_values(nodes) do
          result = Marshal.load(Base64.decode64(encoded))
          if Duby::AST::UnquotedValue === result
            result.node
          else
            result
          end
        end
      end

      def __ruby_eval(code, arg)
        Kernel.eval(code)
      end

      def fixnum(value)
        node = eval("1")
        node.literal = value
        node
      end

      def constant(name)
        node = eval("Foo")
        node.name = name
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
        append_node Duby::AST::ClassDefinition.new(@extra_body, position, name, &block)
      end

      def define_closure(position, name, enclosing_type)
        target = self
        parent = @extra_body
        enclosing_type = enclosing_type.unmeta
        if enclosing_type.respond_to?(:node) && enclosing_type.node
          parent = target = enclosing_type.node
        end
        target.append_node(Duby::AST::ClosureDefinition.new(
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
            dpos = Duby::Transform::Transformer::JMetaPosition.new(jpos, jpos)
            print "#{message} at "
            Duby.print_error("", dpos)
          else
            print message
          end
        end
      end
    end

    def parse(src, filename='dash_e', raise_errors=false, transformer=nil)
      ast = parse_ruby(src, filename)
      transformer ||= Transform::Transformer.new(Duby::CompilationState.new)
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
          Duby.print_error(ex.cause.message, position)
        end
        raise ex
      end
    end
    module_function :parse_ruby
  end
end
require 'mirah/transform2'