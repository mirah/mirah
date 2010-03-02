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
      attr_reader :errors
      def initialize
        @errors = []
        @tmp_count = 0
        @annotations = []
        @scopes = []
        @extra_body = nil
      end

      def annotations
        result, @annotations = @annotations, []
        return result
      end

      def add_annotation(annotation)
        @annotations << annotation
        Duby::AST::Noop.new(annotation.parent, annotation.position)
      end

      def tmp
        "__xform_tmp_#{@tmp_count += 1}"
      end

      def transform(node, parent)
        begin
          scope = node.getScope if node.respond_to? :getScope
          if scope
            @scopes << scope
          end
          top = @extra_body.nil?
          if top
            @extra_body = Duby::AST::Body.new(nil, node.position)
          end
          begin
            result = node.transform(self, parent)
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
          ensure
            if scope
              @scopes.pop
            end
          end
        rescue Error => ex
          @errors << ex
          Duby::AST::ErrorNode.new(parent, ex)
        rescue Exception => ex
          error = Error.new(ex.message, node.position, ex)
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
        unless vars.empty?
          src = "#{vars.join ','} = [];begin;#{src};end"
        end
        node = Duby::AST.parse_ruby(src, filename)
        duby_node = transform(node, nil).body
        unless vars.empty?
          # We have
          # (Script (Body ({vars} (NewlineNode (BeginNode ({src}))))))
          duby_node = duby_node.children[1]
        end
        duby_node.parent = parent
        duby_node
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
        append_node Duby::AST::ClassDefinition.new(nil, position, name, &block)
      end
    end
  end
  TransformError = Transform::Error

  module AST
    begin
      Parser = org.jrubyparser.Parser
    rescue NameError
      $CLASSPATH << File.dirname(__FILE__) + '/../../javalib/JRubyParser.jar'
      Parser = org.jrubyparser.Parser
    end
    java_import org.jrubyparser.parser.ParserConfiguration
    java_import org.jrubyparser.CompatVersion
    java_import java.io.StringReader

    def parse(src, filename='-', raise_errors=false, transformer=nil)
      ast = parse_ruby(src, filename)
      transformer ||= Transform::Transformer.new
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
      parser = Parser.new
      config = ParserConfiguration.new(0, CompatVersion::RUBY1_9, true)
      begin
        parser.parse(filename, StringReader.new(src), config)
      rescue => ex
        if ex.cause.respond_to? :position
          position = ex.cause.position
          Duby.print_error(ex.cause.message, position)
        end
        raise ex
      end
    end
    module_function :parse_ruby

    JRubyAst = org.jrubyparser.ast

    module CallOpAssignment
      def call_op_assignment(transformer, parent, name, args)
        set_args = JRubyAst::ListNode.new(position)
        set_args.add_all(args)
        set_args.add(value_node)

        first = JRubyAst::CallNode.new(position, receiver_node, name, args)
        second = JRubyAst::AttrAssignNode.new(position, receiver_node,
                                              "#{name}=", set_args)

        if operator_name == '||'
          klass = JRubyAst::OrNode
        elsif operator_name == '&&'
          klass = JRubyAst::AndNode
        else
          raise "Unknown OpAsgn operator #{operator_name}"
        end
        transformer.transform(klass.new(position, first, second), parent)
      end
    end

    # reload
    module JRubyAst
      class Node
        def transform(transformer, parent)
          # default behavior is to raise, to expose missing nodes
          raise TransformError.new("Unsupported syntax: #{self}", position)
        end

        def [](ix)
          self.child_nodes[ix]
        end

        def inspect(indent = 0)
          s = ' '*indent + self.class.name.split('::').last

          if self.respond_to?(:name)
            s << " |#{self.name}|"
          end
          if self.respond_to?(:value)
            s << " ==#{self.value.inspect}"
          end

          if self.respond_to?(:index)
            s << " &#{self.index.inspect}"
          end

          if self.respond_to?(:depth)
            s << " >#{self.depth.inspect}"
          end

          [:receiver_node, :args_node, :var_node, :head_node, :value_node, :iter_node, :body_node, :next_node, :condition, :then_body, :else_body].each do |mm|
            if self.respond_to?(mm)
              begin
                s << "\n#{self.send(mm).inspect(indent+2)}" if self.send(mm)
              rescue
                s << "\n#{' '*(indent+2)}#{self.send(mm).inspect}" if self.send(mm)
              end
            end
          end

          if org::jruby::ast::ListNode === self
            (0...self.size).each do |n|
              begin
                s << "\n#{self.get(n).inspect(indent+2)}" if self.get(n)
              rescue
                s << "\n#{' '*(indent+2)}#{self.get(n).inspect}" if self.get(n)
              end
            end
          end
          s
        end

        def signature(parent)
          nil
        end
      end

      class ListNode
        include Enumerable

        def each(&block)
          child_nodes.each(&block)
        end
      end

      class ArgsNode
        def args
          has_typed = optional &&
              optional.child_nodes.all? {|n| n.kind_of? TypedArgumentNode}
          if has_typed
            optional
          else
            pre
          end
        end

        def transform(transformer, parent)
          Arguments.new(parent, position) do |args_node|
            arg_list = args.child_nodes.map do |node|
              if !node.respond_to?(:type_node) || node.type_node.respond_to?(:type_reference)
                RequiredArgument.new(args_node, node.position, node.name)
              else
                OptionalArgument.new(args_node, node.position, node.name) {|opt_arg| [transformer.transform(node, opt_arg)]}
              end
              # argument nodes will have type soon
              #RequiredArgument.new(args_node, node.name, node.type)
            end if args

            # TODO optional arguments.
            opt_list = optional.child_nodes.map do |node|
              OptionalArgument.new(args_node, node.position) {|opt_arg| [transformer.transform(node, opt_arg)]}
            end if false && optional

            rest_arg = RestArgument.new(args_node, rest.position, rest.name) if rest

            block_arg = BlockArgument.new(args_node, block.position, block.name) if block

            [arg_list, opt_list, rest_arg, block_arg]
          end
        end
      end

      class ArrayNode
        def transform(transformer, parent)
          Array.new(parent, position) do |array|
            child_nodes.map {|child| transformer.transform(child, array)}
          end
        end
      end

      class AttrAssignNode
        def transform(transformer, parent)
          case name
          when '[]='
            Call.new(parent, position, name) do |call|
              [
                transformer.transform(receiver_node, call),
                args_node ? args_node.child_nodes.map {|arg| transformer.transform(arg, call)} : [],
                nil
              ]
            end
          else
            new_name = name[0..-2] + '_set'
            Call.new(parent, position, new_name) do |call|
              [
                transformer.transform(receiver_node, call),
                args_node ? args_node.child_nodes.map {|arg| transformer.transform(arg, call)} : [],
                nil
              ]
            end
          end
        end
      end

      class BeginNode
        def transform(transformer, parent)
          transformer.transform(body_node, parent)
        end
      end

      class BlockNode
        def transform(transformer, parent)
          Body.new(parent, position) do |body|
            child_nodes.map {|child| transformer.transform(child, body)}
          end
        end
      end

      class BreakNode
        def transform(transformer, parent)
          # TODO support 'break value'?
          Break.new(parent, position)
        end
      end

      class ClassNode
        def transform(transformer, parent)
          ClassDefinition.new(parent, position,
                              cpath.name,
                              transformer.annotations) do |class_def|
            [
              super_node ? super_node.type_reference(class_def) : nil,
              body_node ? transformer.transform(body_node, class_def) : nil
            ]
          end
        end
      end

      class DStrNode
        def transform(transformer, parent)
          StringConcat.new(parent, position) do |p|
            child_nodes.map{|n| n.transform(transformer, p)}
          end
        end
      end

      class EvStrNode
        def transform(transformer, parent)
          ToString.new(parent, position) do |p|
            [body.transform(transformer, p)]
          end
        end
      end

      class GlobalVarNode
        def transform(transformer, parent)
          classname = name[1..-1]
          annotation = Annotation.new(parent, position, AST.type(classname))
          transformer.add_annotation(annotation)
        end
      end

      class CallNode
        def transform(transformer, parent)
          if annotation?
            return transformer.add_annotation(annotation(transformer, parent))
          end

          actual_name = name
          case actual_name
          when '[]'
            # could be array instantiation
            case receiver_node
            when VCallNode
              case receiver_node.name
              when 'boolean', 'byte', 'short', 'char', 'int', 'long', 'float', 'double'
                return EmptyArray.new(parent, position, AST::type(receiver_node.name)) do |array|
                  transformer.transform(args_node.get(0), array)
                end
              # TODO look for imported, lower case class names
              end
            when ConstNode
              return EmptyArray.new(parent, position, AST::type(receiver_node.name)) do |array|
                transformer.transform(args_node.get(0), array)
              end
            end
          when /=$/
            if name.size > 2 || name =~ /^\w/
              actual_name = name[0..-2] + '_set'
            end
          end

          Call.new(parent, position, actual_name) do |call|
            [
              transformer.transform(receiver_node, call),
              args_node ? args_node.child_nodes.map {|arg| transformer.transform(arg, call)} : [],
              iter_node ? transformer.transform(iter_node, call) : nil
            ]
          end
        end

        def type_reference(parent)
          if name == "[]"
            # array type, top should be a constant; find the rest
            array = true
            elements = []
          else
            array = false
            elements = [name]
          end

          receiver = receiver_node

          loop do
            case receiver
            when ConstNode
              elements << receiver_node.name
              break
            when CallNode
              elements.unshift(receiver.name)
              receiver = receiver.receiver_node
            when SymbolNode
              elements.unshift(receiver.name)
              break
            when VCallNode
              elements.unshift(receiver.name)
              break
            when GlobalVarNode
              elements.unshift(receiver.name[1..-1])
              break
            end
          end

          # join and load
          class_name = elements.join(".")
          AST::type(class_name, array)
        end

        def annotation(transformer, parent)
          if name == '[]'
            annotation = receiver_node.annotation(transformer, parent)
            value = args_node[0]
            case value
            when HashNode
              values = value.list_node
              (0..(values.size / 2)).each do |i|
                name = values.get(2 * i).name
                value = values.get(2 * i + 1)
                annotation[name] = transformer.transform(value, annotation)
              end
            when nil
              # ignore an empty argument list
            else
              annotation['value'] = transformer.transform(value, annotation)
            end
            annotation
          else
            klass = type_reference(parent)
            Annotation.new(parent, position, klass)
          end
        end

        def annotation?
          if name == '[]'
            receiver = receiver_node
          else
            receiver = self
          end
          receiver = receiver.receiver_node while CallNode === receiver
          GlobalVarNode === receiver
        end
      end

      class Colon2Node
      end

      class ConstNode
        def transform(transformer, parent)
          Constant.new(parent, position, name)
        end

        def type_reference(parent)
          AST::type(name, false, false)
        end
      end

      class DefnNode
        def transform(transformer, parent)
          actual_name = name
          if name =~ /=$/
            actual_name = name[0..-2] + '_set'
          end
          if name == 'initialize'
            klass = ConstructorDefinition
          else
            klass = MethodDefinition
          end
          klass.new(parent,
                    position,
                    actual_name,
                    transformer.annotations) do |defn|
            signature = {:return => nil}

            if args_node && args_node.args
              args_node.args.child_nodes.each do |arg|
                if arg.respond_to?(:type_node) && arg.type_node.respond_to?(:type_reference)
                  signature[arg.name.intern] =
                    arg.type_node.type_reference(parent)
                end
              end
            end
            if body_node
              for node in body_node.child_nodes
                sig = node.signature(defn)
                break unless sig
                signature.update(sig) if sig.kind_of? ::Hash
              end
            end
            [
              signature,
              args_node ? transformer.transform(args_node, defn) : nil,
              body_node ? transformer.transform(body_node, defn) : nil
            ]
          end
        end
      end

      class DefsNode
        def transform(transformer, parent)
          actual_name = name
          if name =~ /=$/
            actual_name = name[0..-2] + '_set'
          end
          StaticMethodDefinition.new(parent,
                                     position,
                                     actual_name,
                                     transformer.annotations) do |defn|
            signature = {:return => nil}
            if args_node && args_node.args
              args_node.args.child_nodes.each do |arg|
                if arg.respond_to? :type_node
                  signature[arg.name.intern] =
                    arg.type_node.type_reference(parent)
                end
              end
            end
            if body_node
              for node in body_node.child_nodes
                sig = node.signature(defn)
                break unless sig
                signature.update(sig) if sig.kind_of? ::Hash
              end
            end
            [
              signature,
              args_node ? transformer.transform(args_node, defn) : nil,
              body_node ? transformer.transform(body_node, defn) : nil
            ]
          end
        end
      end

      class FalseNode
        def transform(transformer, parent)
          Boolean.new(parent, position, false)
        end
      end

      class FCallNode
        def signature(parent)
          case name
          when "returns"
            @declaration = true
            {:return => args_node.get(0).type_reference(parent)}
          when "throws"
            @declaration = true
            exceptions = args_node.child_nodes.map do |node|
              node.type_reference(parent)
            end
            {:throws =>  exceptions}
          else
            nil
          end
        end

        def transform(transformer, parent)
          @declaration ||= false

          if @declaration
            return Noop.new(parent, position)
          end

          macro = AST.macro(name)
          if macro
            transformer.expand(self, parent, &macro)
          else
            FunctionalCall.new(parent, position, name) do |call|
              [
                args_node ? args_node.child_nodes.map {|arg| transformer.transform(arg, call)} : [],
                iter_node ? transformer.transform(iter_node, call) : nil
              ]
            end
          end
        end

        def type_reference(parent)
          AST::type(name)
        end
      end

      class FixnumNode
        def transform(transformer, parent)
          AST::fixnum(parent, position, value)
        end
      end

      class FloatNode
        def transform(transformer, parent)
          AST::float(parent, position, value)
        end
      end

      class HashNode
        def transform(transformer, parent)
          @declaration ||= false

          if @declaration
            Noop.new(parent, position)
          else
            super
          end
        end

        # Create a signature definition using a literal hash syntax
        def signature(parent)
          # flag this as a declaration, so it transforms to a noop
          @declaration = true

          arg_types = {:return => nil}

          list = list_node.child_nodes.to_a
          list.each_index do |index|
            if index % 2 == 0
              if SymbolNode === list[index] && list[index].name == 'return'
                arg_types[:return] = list[index + 1].type_reference(parent)
              else
                arg_types[list[index].name.intern] = list[index + 1].type_reference(parent)
              end
            end
          end
          return arg_types
        end
      end

      class IfNode
        def transform(transformer, parent)
          If.new(parent, position) do |iff|
            [
              Condition.new(iff, condition.position) {|cond| [transformer.transform(condition, cond)]},
              then_body ? transformer.transform(then_body, iff) : nil,
              else_body ? transformer.transform(else_body, iff) : nil
            ]
          end
        end
      end

      class AndNode
        def transform(transformer, parent)
          If.new(parent, position) do |iff|
            [
              Condition.new(iff, first_node.position) {|cond| [transformer.transform(first_node, cond)]},
              transformer.transform(second_node, iff),
              nil
            ]
          end
        end
      end

      class OpAsgnAndNode
        def transform(transformer, parent)
          transformer.transform(
              AndNode.new(position, first_node, second_node), parent)
        end
      end

      class OrNode
        def transform(transformer, parent)
          Body.new(parent, position) do |block|
            temp = transformer.tmp
            [
              LocalAssignment.new(block, first_node.position, temp) do |l|
                [transformer.transform(first_node, l)]
              end,
              If.new(parent, position) do |iff|
                [
                  Condition.new(iff, first_node.position) do |cond|
                    [Local.new(cond, first_node.position, temp)]
                  end,
                  Local.new(iff, first_node.position, temp),
                  transformer.transform(second_node, iff)
                ]
              end
            ]
          end
        end
      end

      class OpAsgnOrNode
        def transform(transformer, parent)
          transformer.transform(
              OrNode.new(position, first_node, second_node), parent)
        end
      end

      class OpAsgnNode
        include CallOpAssignment
        def transform(transformer, parent)
          call_op_assignment(transformer, parent,
                             variable_name, ListNode.new(position))
        end
      end

      class OpElementAsgnNode
        include CallOpAssignment
        def transform(transformer, parent)
          Body.new(parent, position) do |block|
            temps = []
            arg_init = args_node.map do |arg|
              temps << transformer.tmp
              LocalAssignment.new(block, arg.position, temps[-1]) do |l|
                [transformer.transform(arg, l)]
              end
            end
            args = ListNode.new(position)
            args_node.zip(temps) do |arg, temp_name|
              args.add(LocalVarNode.new(arg.position, 0, temp_name))
            end
            arg_init + [call_op_assignment(transformer, parent, '[]', args)]
          end
        end
      end

      class RescueNode
        def transform(transformer, parent)
          Rescue.new(parent, position) do |node|
            [
              transformer.transform(body_node, node),
              rescue_node ? transformer.transform(rescue_node, node) : []
            ]
          end
        end
      end

      class RescueBodyNode
        def transform(transformer, parent)
          children = if opt_rescue_node
            transformer.transform(opt_rescue_node, parent)
          else
            []
          end
          [
            RescueClause.new(parent, position) do |clause|
              exceptions = if exception_nodes
                exception_nodes.map {|e| e.type_reference(clause)}
              else
                [AST.type('java.lang.Exception')]
              end
              [
                exceptions,
                transformer.transform(body_node, clause)
              ]
            end,
            *children
          ]
        end
      end

      class EnsureNode
        def transform(transformer, parent)
          Ensure.new(parent, position) do |node|
            child_nodes.map {|c| transformer.transform(c, node)}
          end
        end
      end

      class NilImplicitNode
        def transform(transformer, parent)
          Noop.new(parent, position)
        end
      end

      class NilNode
        def transform(transformer, parent)
          Null.new(parent, position)
        end
      end

      class InstAsgnNode
        def transform(transformer, parent)
          case value_node
          when SymbolNode, ConstNode
            FieldDeclaration.new(parent, position,
                                 name, transformer.annotations) do |field_decl|
              [value_node.type_reference(field_decl)]
            end
          else
            FieldAssignment.new(parent, position, name, transformer.annotations) {|field| [transformer.transform(value_node, field)]}
          end
        end
      end

      class InstVarNode
        def transform(transformer, parent)
          Field.new(parent, position, name, transformer.annotations)
        end
      end

      class LocalAsgnNode
        def transform(transformer, parent)
          captured = transformer.captured?(self)
          case value_node
          when SymbolNode, ConstNode
            LocalDeclaration.new(parent, position, name, captured) {|local_decl| [value_node.type_reference(local_decl)]}
          when JRubyAst::GlobalVarNode
            real_parent = parent
            real_parent = parent.parent if Body === real_parent
            if value_node.name == '$!' && RescueClause === real_parent
              real_parent.name = name
              Noop.new(parent, position)
            else
              raise "Illegal global variable"
            end
          else
            LocalAssignment.new(parent, position, name, captured) {|local| [transformer.transform(value_node, local)]}
          end
        end
      end

      class LocalVarNode
        def transform(transformer, parent)
          Local.new(parent, position, name, transformer.captured?(self))
        end
      end

      class ModuleNode
      end

      class NewlineNode
        def transform(transformer, parent)
          actual = transformer.transform(next_node, parent)
          actual.newline = true
          actual
        end

        # newlines are bypassed during signature transformation
        def signature(parent)
          next_node.signature(parent)
        end
      end

      class NextNode
        def transform(transformer, parent)
          # TODO support 'next value'?
          Next.new(parent, position)
        end
      end

      class NotNode
        def transform(transformer, parent)
          Not.new(parent, position) {|nott| [transformer.transform(condition_node, nott)]}
        end
      end

      class RedoNode
        def transform(transformer, parent)
          Redo.new(parent, position)
        end
      end

      class ReturnNode
        def transform(transformer, parent)
          Return.new(parent, position) do |ret|
            [transformer.transform(value_node, ret)]
          end
        end
      end

      class RootNode
        def getScope
          getStaticScope
        end

        def transform(transformer, parent)
          Script.new(parent, position) {|script| [transformer.transform(child_nodes[0], script)]}
        end
      end

      class SelfNode
      end

      class StrNode
        def transform(transformer, parent)
          String.new(parent, position, value)
        end

        def type_reference(parent)
          AST::type(value)
        end
      end

      class SymbolNode
        def type_reference(parent)
          AST::type(name)
        end
      end

      class TrueNode
        def transform(transformer, parent)
          Boolean.new(parent, position, true)
        end
      end

      class TypedArgumentNode
        def transform(transformer, parent)
          type_node.transform(transformer, parent)
        end
      end

      class VCallNode
        def transform(transformer, parent)
          if name == 'raise'
            Raise.new(parent, position) do
              []
            end
          elsif name == 'null'
            Null.new(parent, position)
          else
            macro = AST.macro(name)
            if macro
              transformer.expand(self, parent, &macro)
            else
              FunctionalCall.new(parent, position, name) do |call|
                [
                  [],
                  nil
                ]
              end
            end
          end
        end

        def type_reference(parent)
          AST::type name
        end
      end

      class WhileNode
        def transform(transformer, parent)
          Loop.new(parent, position, evaluate_at_start, false) do |loop|
            [
              Condition.new(loop, condition_node.position) {|cond| [transformer.transform(condition_node, cond)]},
              transformer.transform(body_node, loop)
            ]
          end
        end
      end

      class UntilNode
        def transform(transformer, parent)
          Loop.new(parent, position, evaluate_at_start, true) do |loop|
            [
              Condition.new(loop, condition_node.position) {|cond| [transformer.transform(condition_node, cond)]},
              transformer.transform(body_node, loop)
            ]
          end
        end
      end

      class DVarNode
        def transform(transformer, parent)
          # TODO does this need to be handled specially?
          Local.new(parent, position, name, transformer.captured?(self))
        end
      end

      class DAsgnNode
        def transform(transformer, parent)
          captured = transformer.captured?(self)
          case value_node
          when SymbolNode, ConstNode
            LocalDeclaration.new(parent, position, name, captured) {|local_decl| [value_node.type_reference(local_decl)]}
          else
            LocalAssignment.new(parent, position, name, captured) {|local| [transformer.transform(value_node, local)]}
          end
        end
      end

      class IterNode
        def transform(transformer, parent)
          Block.new(parent, position) do |block|
            [
              transformer.transform(var_node, block),
              transformer.transform(body_node, block)
            ]
          end
        end
      end

      class ForNode
        def transform(transformer, parent)
          Call.new(parent, position, 'each') do |each|
            [
              transformer.transform(iter_node, each),
              [],
              Block.new(each, body_node.position) do |block|
                [
                  Arguments.new(block, var_node.position) do |args|
                    [
                      # TODO support for multiple assignment?
                      [RequiredArgument.new(args,
                                            var_node.position,
                                            var_node.name)
                      ]
                    ]
                  end,
                  transformer.transform(body_node, block)
                ]
              end
            ]
          end
        end
      end

      class SuperNode
        def transform(transformer, parent)
          Super.new(parent, position) do
            [args_node ? args_node.map {|arg| transformer.transform(arg, parent)} : []]
          end
        end
      end

      class ZSuperNode
        def transform(transformer, parent)
          Super.new(parent, position)
        end
      end

      class SelfNode
        def transform(transformer, parent)
          Self.new(parent, position)
        end
      end
    end
  end
end
