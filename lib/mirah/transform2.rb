module Duby::AST
  class TransformHelper
    java_import 'jmeta.Ast'
    def initialize(transformer)
      @mirah = transformer
    end

    def position(node)
      @mirah.position(node)
    end

    def transformer
      @mirah
    end

    def transform(node, parent)
      @mirah.transform(node, parent)
    end

    def typeref(node, parent)
      @mirah.type_reference(node, parent)
    end

    def signature(node, parent)
      if node[0] == 'FCall'
        name = node[1]
        args = node[2]
        case node[1]
        when 'returns'
          def node.declaration?
            true
          end
          return {:return => transformer.type_reference(args[0], parent)}
        when 'throws'
          def node.declaration?
            true
          end
          exceptions = args.map {|n| transformer.type_reference(n, parent)}
          return {:throws => exceptions}
        end
      end
      return nil
    end

    def transform_script(node, parent)
      Script.new(parent, position(node)) {|script| [@mirah.transform(node.children[0], script)]}
    end

    def transform_fixnum(node, parent)
      Duby::AST::fixnum(parent, position(node), node[1])
    end

    def transform_float(node, parent)
      Duby::AST::float(parent, position(node), node[1])
    end

    def transform_true(node, parent)
      Boolean.new(parent, position(node), true)
    end

    def transform_false(node, parent)
      Boolean.new(parent, position(node), false)
    end

    def transform_nil(node, parent)
      Null.new(parent, position(node))
    end

    def transform_self(node, parent)
      Self.new(parent, position(node))
    end

    def transform_string(node, parent)
      String.new(parent, position(node), node[1])
    end

    def typeref_string(node, parent)
      Duby::AST::Type(node[1])
    end

    def transform_symbol(node, parent)
      String.new(parent, position(node), node[1])
    end

    def typeref_symbol(node, parent)
      Duby::AST::Type(node[1])
    end
    def transform_body(node, parent)
      Body.new(parent, position(node)) do |body|
        node.children.map {|child| @mirah.transform(child, body)}
      end
    end

    def transform_begin(node, parent)
      @mirah.transform(node[1], parent)
    end

    def transform_break(node, parent)
      Break.new(parent, position(node))
    end

    def transform_arguments(node, parent)
      Arguments.new(parent, position(node)) do |args_node|
        node.children.map do |child|
          if child.nil?
            nil
          elsif child.kind_of?(Ast)
            @mirah.transform(child, args_node)
          else
            child.map {|x| @mirah.transform(x, args_node)}
          end
        end
      end
    end

    def transform_required_argument(node, parent)
      name = node[1]
      type = node[2]
      if type
        defn = parent.parent
        defn.signature[name.intern] = @mirah.type_reference(type, parent)
      end
      RequiredArgument.new(parent, position(node), name)
    end

    def transform_opt_arg(node, parent)
      name = node[1]
      type = node[2]
      value = node[3]
      if type
        defn = parent.parent
        defn.signature[name.intern] = @mirah.type_reference(type, parent)
      end
      OptionalArgument.new(parent, position(node), name) {|optarg| [@mirah.transform(value, optarg)]}
    end

    def transform_rest_arg(node, parent)
      name = node[1]
      type = node[2]
      if type
        defn = parent.parent
        defn.signature[name.intern] = @mirah.type_reference(type, parent)
      end
      RestArgument.new(parent, position(node), name)
    end

    def transform_block_arg(node, parent)
      name = node[1]
      type = node[2]
      if type
        defn = parent.parent
        defn.signature[name.intern] = @mirah.type_reference(type, parent)
      end
      BlockArgument.new(parent, position(node), name)
    end
    # TODO OptBlockArg, UnnamedRestArg

    def transform_sclass(node, parent)
      ClassAppendSelf.new(parent, position(node)) do |class_append_self|
        raise "Singleton class not supported" unless node[1][0] == 'Self'

        node[2].children.map do |child|
          transformer.transform(child, class_append_self)
        end
      end
    end

    def transform_array(node, parent)
      Array.new(parent, position(node)) do |array|
        node.children.map {|child| transformer.transform(child, array)}
      end
    end

    def transform_attr_assign(node, parent)
      name = node[1]
      target = node[2]
      args = node[3]
      position = position(node)
      case name
      when '[]='
        Call.new(parent, position, name) do |call|
          [
            transformer.transform(target, call),
            args.map {|arg| transformer.transform(arg, call)},
            nil
          ]
        end
      else
        new_name = name[0..-2] + '_set'
        Call.new(parent, position, new_name) do |call|
          [
            transformer.transform(target, call),
            args.map {|arg| transformer.transform(arg, call)},
            nil
          ]
        end
      end
    end

    def transform_class(node, parent)
      cpath = node[1]
      body_node = node[2]
      super_node = node[3]
      if cpath[0] == 'Constant'
        name = cpath[1]
      elsif cpath[0] == 'Unquote'
        name = cpath
      else
        raise "Unsupported class name #{cpath[0]}"
      end
      ClassDefinition.new(parent, position(node),
                          name,
                          transformer.annotations) do |class_def|
        [
          super_node ? transfomer.type_reference(super_node, class_def) : nil,
          body_node ? transformer.transform(body_node, class_def) : nil
        ]
      end
    end

    def transform_def(node, parent)
      name, args_node, body_node = node[1], node[2], node[3]
      position = position(node)
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
        defn.signature = signature = {:return => nil}

        if body_node
          for node in body_node.children
            sig = signature(node, defn)
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

    def transform_defstatic(node, parent)
      name, args_node, body_node = node[1], node[2], node[3]
      position = position(node)
      actual_name = name
      if name =~ /=$/
        actual_name = name[0..-2] + '_set'
      end
      StaticMethodDefinition.new(parent,
                                 position,
                                 actual_name,
                                 transformer.annotations) do |defn|
        defn.signature = signature = {:return => nil}

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

    def transform_fcall(node, parent)
      if node.respond_to?(:declaration?) && node.declaration
        return Noop.new(parent, position(node))
      end

      name = node[1]
      args = node[2]
      iter_node = node[3]
      fcall = FunctionalCall.new(parent, position(node), name) do |call|
        [
          args ? args.map {|arg| transformer.transform(arg, call)} : [],
          iter_node ? transformer.transform(iter_node, call) : nil
        ]
      end
      macro = Duby::AST.macro(name)
      if macro
        transformer.expand(fcall, parent, &macro)
      else
        fcall
      end
    end

    def typeref_fcall(fcall, parent)
      name = fcall[1]
      Duby::AST::type(name)
    end

    def transform_constant(node, parent)
      Constant.new(parent, position(node), node[1])
    end

    def typeref_constant(node, parent)
      name = node[1]
      Duby::AST::type(name)
    end

    def transform_identifier(node, parent)
      name = node[1]
      position = position(node)
      if name == 'raise'
        Raise.new(parent, position) do
          []
        end
      elsif name == 'null'
        Null.new(parent, position)
      elsif ['public', 'private', 'protected'].include?(name)
        AccessLevel.new(parent, position, name)
      else
        macro = AST.macro(name)
        fcall = FunctionalCall.new(parent, position, name) do |call|
          [
            [],
            nil
          ]
        end
        if macro
          transformer.expand(fcall, parent, &macro)
        else
          fcall
        end
      end
    end

    def typeref_identifier(node, parent)
      name = node[1]
      Duby::AST::type(name)
    end

    def transform_(node, parent)
    end


  end
end