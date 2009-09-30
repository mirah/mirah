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
      end
      
      def transform(node, parent)
        begin
          node.transform(self, parent)
        rescue Error => ex
          @errors << ex
          Duby::AST::ErrorNode.new(parent, ex)
        rescue Exception => ex
          error = Transform::Error.new(ex.message, node.position, ex)
          @errors << error
          Duby::AST::ErrorNode.new(parent, error)
        end
      end
    end
  end
  TransformError = Transform::Error

  module AST
    def parse(src)
      ast = JRuby.parse(src)
      Transform::Transformer.new.transform(ast, nil)
    end
    module_function :parse

    # reload 
    module Java::OrgJrubyAst
      class Node
        def transform(transformer, parent)
          # default behavior is to raise, to expose missing nodes
          raise TransformError.new("Unsupported syntax: #{self}", position)
        end
        
        def signature(parent)
          nil
        end
        
        def line_number
          position.start_line + 1 rescue nil
        end
      end

      class ArgsNode
        def transform(transformer, parent)
          Arguments.new(parent, line_number) do |args_node|
            arg_list = args.child_nodes.map do |node|
              RequiredArgument.new(args_node, node.line_number, node.name)
              # argument nodes will have type soon
              #RequiredArgument.new(args_node, node.name, node.type)
            end if args

            opt_list = opt_args.child_nodes.map do |node|
              OptionalArgument.new(args_node, node.line_number) {|opt_arg| [transformer.transform(node, opt_arg)]}
            end if opt_args

            rest_arg = RestArgument.new(args_node, rest_arg_node.line_number, rest_arg_node.name) if rest_arg_node

            block_arg = BlockArgument.new(args_node, block_arg_node.line_number, block_arg_node.name) if block_arg_node

            [arg_list, opt_list, rest_arg, block_arg]
          end
        end
      end

      class ArrayNode
        def transform(transformer, parent)
          Array.new(parent, line_number) do |array|
            child_nodes.map {|child| transformer.transform(child, array)}
          end
        end
      end

      class AttrAssignNode
        def transform(transformer, parent)
          case name
          when '[]='
            Call.new(parent, line_number, name) do |call|
              [
                transformer.transform(receiver_node, call),
                args_node ? args_node.child_nodes.map {|arg| transformer.transform(arg, call)} : [],
                nil
              ]
            end
          else
            new_name = name[0..-2] + '_set'
            Call.new(parent, line_number, new_name) do |call|
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
          Body.new(parent, line_number) do |body|
            child_nodes.map {|child| transformer.transform(child, body)}
          end
        end
      end

      class BreakNode
        def transform(transformer, parent)
          # TODO support 'break value'?
          Break.new(parent, line_number)
        end
      end
      
      class ClassNode
        def transform(transformer, parent)
          ClassDefinition.new(parent, line_number, cpath.name) do |class_def|
            [
              super_node ? transformer.transform(super_node, class_def) : nil,
              body_node ? transformer.transform(body_node, class_def) : nil
            ]
          end
        end
      end

      class CallNode
        def transform(transformer, parent)
          actual_name = name
          case actual_name
          when '[]'
            # could be array instantiation
            case receiver_node
            when VCallNode
              case receiver_node.name
              when 'boolean', 'byte', 'short', 'char', 'int', 'long', 'float', 'double'
                return EmptyArray.new(parent, line_number, AST::type(receiver_node.name)) do |array|
                  transformer.transform(args_node.get(0), array)
                end
              # TODO look for imported, lower case class names
              end
            when ConstNode
              return EmptyArray.new(parent, line_number, AST::type(receiver_node.name)) do |array|
                transformer.transform(args_node.get(0), array)
              end
            end
          when /=$/
            actual_name = name[0..-2] + '_set'
          end
          
          Call.new(parent, line_number, name) do |call|
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
            end
          end

          # join and load
          class_name = elements.join(".")
          AST::type(class_name, array)
        end
      end

      class Colon2Node
      end

      class ConstNode
        def transform(transformer, parent)
          Constant.new(parent, line_number, name)
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
          MethodDefinition.new(parent, line_number, actual_name) do |defn|
            signature = {:return => nil}

            if args_node && args_node.args && TypedArgumentNode === args_node.args[0]
              args_node.args.child_nodes.each do |arg|
                signature[arg.name.intern] = arg.type_node.type_reference(parent)
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
          StaticMethodDefinition.new(parent, line_number, actual_name) do |defn|
            signature = {:return => nil}

            if args_node && args_node.args && TypedArgumentNode === args_node.args[0]
              args_node.args.child_nodes.each do |arg|
                signature[arg.name.intern] = arg.type_node.type_reference(parent)
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
          Boolean.new(parent, line_number, false)
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
          # TODO This should probably be pluggable
          @declaration ||= false

          if @declaration
            return Noop.new(parent, line_number)
          end

          case name
          when "import"
            case args_node
            when ArrayNode
              case args_node.size
              when 1
                case args_node.get(0)
                when StrNode
                  long = args_node.get(0).value
                  short = long[(long.rindex('.') + 1)..-1]
                when Java::OrgJrubyAst::CallNoArgNode
                  node = args_node.get(0)
                  pieces = [node.name]
                  while node.kind_of? CallNode
                    node = node.receiver_node
                    pieces << node.name
                  end
                  long = pieces.reverse.join '.'
                  short = pieces[0]
                when Java::OrgJrubyAst::CallOneArgNode
                  arg = args_node.get(0).args_node.get(0)
                  unless FCallOneArgNode === arg && arg.name == 'as'
                    raise TransformError.new("unknown import syntax", args_node)
                  end
                  short = arg.args_node.get(0).name
                  node = args_node.get(0)
                  pieces = [node.name]
                  while node.kind_of? CallNode
                    node = node.receiver_node
                    pieces << node.name
                  end
                  long = pieces.reverse.join '.'
                else
                  raise TransformError.new("unknown import syntax", args_node)
                end
              when 2
                short = args_node.child_nodes[0].value
                long = args_node.child_nodes[1].value
              else
                raise TransformError.new("unknown import syntax", args_node)
              end
            else
              raise TransformError.new("unknown import syntax", args_node)
            end
            Import.new(parent, line_number, short, long)
          when "puts"
            PrintLine.new(parent, line_number) do |println|
              args_node ? args_node.child_nodes.map {|arg| transformer.transform(arg, println)} : []
            end
          when "null"
            Null.new(parent, line_number)
          when "implements"
            interfaces = args_node.child_nodes.map do |interface|
              interface.type_reference(parent)
            end
            parent.parent.implements(*interfaces)
            Noop.new(parent, line_number)
          when "interface"
            raise "Interface name required" unless args_node
            interfaces = args_node.child_nodes.to_a
            interface_name = interfaces.shift
            if Java::OrgJrubyAst::CallOneArgNode === interface_name
              interfaces.unshift(interface_name.args_node.get(0))
              interface_name = interface_name.receiver_node
            end
            raise 'Interface body required' unless iter_node
            InterfaceDeclaration.new(parent, line_number,
                                     interface_name.name) do |interface|
              [interfaces.map {|p| p.type_reference(interface)},
               if iter_node.body_node
                 transformer.transform(iter_node.body_node, interface)
               end
              ]
            end
          else
            FunctionalCall.new(parent, line_number, name) do |call|
              [
                args_node ? args_node.child_nodes.map {|arg| transformer.transform(arg, call)} : [],
                iter_node ? transformer.transform(iter_node, call) : nil
              ]
            end
          end
        end
      end

      class FixnumNode
        def transform(transformer, parent)
          AST::fixnum(parent, line_number, value)
        end
      end

      class FloatNode
        def transform(transformer, parent)
          AST::float(parent, line_number, value)
        end
      end

      class HashNode
        def transform(transformer, parent)
          @declaration ||= false

          if @declaration
            Noop.new(parent, line_number)
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
          If.new(parent, line_number) do |iff|
            [
              Condition.new(iff, condition.line_number) {|cond| [transformer.transform(condition, cond)]},
              then_body ? transformer.transform(then_body, iff) : nil,
              else_body ? transformer.transform(else_body, iff) : nil
            ]
          end
        end
      end

      class NilImplicitNode
        def transform(transformer, parent)
          Noop.new(parent, line_number)
        end
      end

      class NilNode
        def transform(transformer, parent)
          Null.new(parent, line_number)
        end
      end

      class InstAsgnNode
        def transform(transformer, parent)
          case value_node
          when SymbolNode, ConstNode
            FieldDeclaration.new(parent, line_number, name) {|field_decl| [value_node.type_reference(field_decl)]}
          else
            FieldAssignment.new(parent, line_number, name) {|field| [transformer.transform(value_node, field)]}
          end
        end
      end

      class InstVarNode
        def transform(transformer, parent)
          Field.new(parent, line_number, name)
        end
      end

      class LocalAsgnNode
        def transform(transformer, parent)
          case value_node
          when SymbolNode, ConstNode
            LocalDeclaration.new(parent, line_number, name) {|local_decl| [value_node.type_reference(local_decl)]}
          else
            LocalAssignment.new(parent, line_number, name) {|local| [transformer.transform(value_node, local)]}
          end
        end
      end

      class LocalVarNode
        def transform(transformer, parent)
          Local.new(parent, line_number, name)
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
          Next.new(parent, line_number)
        end
      end

      class NotNode
        def transform(transformer, parent)
          Not.new(parent, line_number) {|nott| [transformer.transform(condition_node, nott)]}
        end
      end

      class RedoNode
        def transform(transformer, parent)
          Redo.new(parent, line_number)
        end
      end

      class ReturnNode
        def transform(transformer, parent)
          Return.new(parent, line_number) do |ret|
            [transformer.transform(value_node, ret)]
          end
        end
      end

      class RootNode
        def transform(transformer, parent)
          Script.new(parent, line_number) {|script| [transformer.transform(child_nodes[0], script)]}
        end
      end

      class SelfNode
      end

      class StrNode
        def transform(transformer, parent)
          String.new(parent, line_number, value)
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
          Boolean.new(parent, line_number, true)
        end
      end
      
      class TypedArgumentNode
      end

      class VCallNode
        def transform(transformer, parent)
          FunctionalCall.new(parent, line_number, name) do |call|
            [
              [],
              nil
            ]
          end
        end
      end

      class WhileNode
        def transform(transformer, parent)
          Loop.new(parent, line_number, evaluate_at_start, false) do |loop|
            [
              Condition.new(loop, condition_node.line_number) {|cond| [transformer.transform(condition_node, cond)]},
              transformer.transform(body_node, loop)
            ]
          end
        end
      end

      class UntilNode
        def transform(transformer, parent)
          Loop.new(parent, line_number, evaluate_at_start, true) do |loop|
            [
              Condition.new(loop, condition_node.line_number) {|cond| [transformer.transform(condition_node, cond)]},
              transformer.transform(body_node, loop)
            ]
          end
        end
      end
    end
  end
end
