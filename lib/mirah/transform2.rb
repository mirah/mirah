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

module Mirah::AST
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

    def transform_script(node, parent)
      Script.new(parent, position(node)) do |script|
        script.filename = transformer.filename
        [@mirah.transform(node.children[0], script)]
      end
    end

    def transform_fixnum(node, parent)
      Mirah::AST::fixnum(parent, position(node), node[1])
    end

    def transform_float(node, parent)
      Mirah::AST::float(parent, position(node), node[1])
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

    def transform_symbol(node, parent)
      String.new(parent, position(node), node[1])
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
      name = transform(name, nil) unless name.kind_of?(::String)
      type = node[2]
      type_node = transform(type, parent) if type
      RequiredArgument.new(parent, position(node), name, type_node)
    end

    def transform_opt_arg(node, parent)
      name = node[1]
      name = transform(name, nil) unless name.kind_of?(::String)
      type = node[2]
      value = node[3]
      OptionalArgument.new(parent, position(node), name) do |optarg| 
        [
          type ? transform(type, optarg) : nil,
          transform(value, optarg),
        ]
      end
    end

    def transform_rest_arg(node, parent)
      name = node[1]
      name = transform(name, nil) unless name.kind_of?(::String)
      type = node[2]
      RestArgument.new(parent, position(node), name) do |restarg|
        [type ? transform(type, restarg) : nil]
      end
    end

    def transform_block_arg(node, parent)
      name = node[1]
      name = transform(name, nil) unless name.kind_of?(::String)
      type = node[2]
      BlockArgument.new(parent, position(node), name) do |blkarg|
        [type ? transform(type, blkarg) : nil]
      end
    end

    def transform_opt_block_arg(node, parent)
      block_arg = transform_block_arg(node, parent)
      block_arg.optional = true
      return block_arg
    end

    # TODO UnnamedRestArg

    def transform_sclass(node, parent)
      ClassAppendSelf.new(parent, position(node)) do |class_append_self|
        raise "Singleton class not supported" unless node[1][0] == 'Self'

        [transformer.transform(node[2], class_append_self)]
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
      args = node[3] + [node[4]]
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
      name = transform(name, nil) unless name.kind_of?(::String)
      ClassDefinition.new(parent, position(node),
                          name,
                          transformer.annotations) do |class_def|
        [
          super_node ? transform(super_node, class_def) : nil,
          body_node ? transform(body_node, class_def) : nil
        ]
      end
    end

    def transform_def(node, parent)
      name, args_node, type_node, body_node = node[1], node[2], node[3], node[4]
      name = transform(name, nil) unless name.kind_of?(::String)
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
        defn.return_type = transform(type_node, defn) if type_node
        [
          signature,
          args_node ? transformer.transform(args_node, defn) : nil,
          body_node ? transformer.transform(body_node, defn) : nil,
        ]
      end
    end

    def transform_def_static(node, parent)
      name, args_node, type_node, body_node = node[1], node[2], node[3], node[4]
      name = transform(name, nil) unless name.kind_of?(::String)
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
        defn.return_type = transform(type_node, defn) if type_node
        [
          signature,
          args_node ? transformer.transform(args_node, defn) : nil,
          body_node ? transformer.transform(body_node, defn) : nil,
        ]
      end
    end

    def transform_fcall(node, parent)
      if node.respond_to?(:declaration?) && node.declaration?
        return Noop.new(parent, position(node))
      end

      name = node[1]
      name = transform(name, nil) unless name.kind_of?(::String)
      args = node[2]
      iter_node = node[3]
      fcall = FunctionalCall.new(parent, position(node), name) do |call|
        [
          args ? args.map {|arg| transformer.transform(arg, call)} : [],
          iter_node ? transformer.transform(iter_node, call) : nil
        ]
      end
      macro = Mirah::AST.macro(name)
      if macro
        transformer.expand(fcall, parent, &macro)
      else
        fcall
      end
    end

    def transform_call(node, parent)
      name = node[1]
      name = transform(name, nil) unless name.kind_of?(::String)
      target = node[2]
      args = node[3]
      iter_node = node[4]
      position = position(node)

      actual_name = name
      case actual_name
      when '[]'
        # could be array instantiation
        case target[0]
        when 'Identifier'
          case target[1]
          when 'boolean', 'byte', 'short', 'char', 'int', 'long', 'float', 'double'
            if args.nil? || args.size == 0
              constant = Constant.new(parent, position, target[1])
              constant.array = true
              return constant
            elsif args && args.size == 1
              return EmptyArray.new(parent, position) do |array|
                [transform(target, array), transform(args[0], array)]
              end
            end
          # TODO look for imported, lower case class names
          end
        when 'Constant'
          if args.nil? || args.size == 0
            constant = Constant.new(parent, position, target[1])
            constant.array = true
            return constant
          elsif args && args.size == 1
            return EmptyArray.new(parent, position) do |array|
              [transform(target, array), transform(args[0], array)]
            end
          end
        end
      when /=$/
        if name.size > 2 || name =~ /^\w/
          actual_name = name[0..-2] + '_set'
        end
      end

      Call.new(parent, position, actual_name) do |call|
        [
          transformer.transform(target, call),
          args ? args.map {|arg| transformer.transform(arg, call)} : [],
          iter_node ? transformer.transform(iter_node, call) : nil
        ]
      end
    end

    def transform_constant(node, parent)
      Constant.new(parent, position(node), node[1])
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
        macro = Mirah::AST.macro(name)
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

    def transform_local_assign(node, parent)
      name = node[1]
      value_node = node[2]
      position = position(node)
      case value_node[0]
      when 'Symbol', 'Constant'
        LocalDeclaration.new(parent, position, name) {|local_decl| [transform(value_node, local_decl)]}
      else
        LocalAssignment.new(parent, position, name) {|local| [transform(value_node, local)]}
      end
    end

    def transform_local(node, parent)
      name = node[1]
      Local.new(parent, position(node), name)
    end

    def transform_iter(node, parent)
      args = node[1]
      body = node[2]
      Block.new(parent, position(node)) do |block|
        [
          args ? transformer.transform(args, block) : Arguments.new(block, position(node)),
          body ? transformer.transform(body, block) : nil,
        ]
      end
    end

    def transform_inst_var(node, parent)
      name = node[1]
      name = transform(name, nil) unless name.kind_of?(::String)
      Field.new(parent, position(node), name, transformer.annotations)
    end

    def transform_inst_var_assign(node, parent)
      name = node[1]
      name = transform(name, nil) unless name.kind_of?(::String)
      value_node = node[2]
      position = position(node)
      case value_node[0]
      when 'Symbol', 'Constant'
        FieldDeclaration.new(parent, position,
                             name, transformer.annotations) do |field_decl|
          [transform(value_node, field_decl)]
        end
      else
        FieldAssignment.new(parent, position, name, transformer.annotations) {|field| [transformer.transform(value_node, field)]}
      end
    end

    def transform_class_var(node, parent)
      name = node[1]
      name = transform(name, nil) unless name.kind_of?(::String)
      Field.new(parent, position(node), name, transformer.annotations, true)
    end

    def transform_class_var_assign(node, parent)
      name = node[1]
      name = transform(name, nil) unless name.kind_of?(::String)
      value_node = node[2]
      position = position(node)
      case value_node[0]
      when 'Symbol', 'Constant'
        FieldDeclaration.new(parent, position,
                             name, transformer.annotations, true) do |field_decl|
          [transform(value_node, field_decl)]
        end
      else
        FieldAssignment.new(parent, position, name, transformer.annotations, true) {|field| [transformer.transform(value_node, field)]}
      end
    end

    def transform_if(node, parent)
      condition = node[1]
      then_body = node[2]
      else_body = node[3]
      If.new(parent, position(node)) do |iff|
        [
          Condition.new(iff, position(condition)) {|cond| [transformer.transform(condition, cond)]},
          then_body ? transformer.transform(then_body, iff) : nil,
          else_body ? transformer.transform(else_body, iff) : nil
        ]
      end
    end

    def transform_zsuper(node, parent)
      Super.new(parent, position(node))
    end

    def transform_super(node, parent)
      args = node[1]
      iter = node[2]
      Super.new(parent, position(node)) do |s|
        [args ? args.map {|arg| transformer.transform(arg, s)} : []]
      end
    end

    def transform_return(node, parent)
      value_node = node[1] if node.size > 1
      Return.new(parent, position(node)) do |ret|
        [value_node ? transform(value_node, ret) : nil]
      end
    end

    def transform_dstring(node, parent)
      StringConcat.new(parent, position(node)) do |p|
        node.children.map{|n| transform(n, p)}
      end
    end

    def transform_ev_string(node, parent)
      ToString.new(parent, position(node)) do |p|
        [transform(node[1], p)]
      end
    end

    def transform_and(node, parent)
      first_node = node[1]
      second_node = node[2]
      If.new(parent, position(node)) do |iff|
        [
          Condition.new(iff, position(first_node)) {|cond| [transform(first_node, cond)]},
          transform(second_node, iff),
          nil
        ]
      end
    end

    def transform_or(node, parent)
      first_node = node[1]
      second_node = node[2]
      Body.new(parent, position(node)) do |block|
        temp = transformer.tmp
        [
          LocalAssignment.new(block, position(first_node), temp) do |l|
            [transform(first_node, l)]
          end,
          If.new(parent, position(node)) do |iff|
            [
              Condition.new(iff, position(first_node)) do |cond|
                [Local.new(cond, position(first_node), temp)]
              end,
              Local.new(iff, position(first_node), temp),
              transform(second_node, iff)
            ]
          end
        ]
      end
    end

    def transform_next(node, parent)
      Next.new(parent, position(node))
    end

    def transform_not(node, parent)
      # TODO it's probably better to keep a not node
      # and actually implement compiling it properly.
      # Bonus points for optimizing branches that use Not's.
      If.new(parent, position(node)) do |iff|
        [
          Condition.new(iff, position(node)) do |cond|
            [ transform(node[1], cond) ]
          end,
          Boolean.new(iff, position(node), false),
          Boolean.new(iff, position(node), true)
        ]
      end
    end

    def transform_redo(node, parent)
      Redo.new(parent, position(node))
    end

    def transform_regex(node, parent)
      contents = node[1]
      modifiers = node[2]
      if contents.size == 1 && contents[0][0] == 'String'
        value = contents[0][1]
        Regexp.new(parent, position(node), value)
      else
        raise "Unsupported regex #{node}"
      end
    end

    def transform_ensure(node, parent)
      Ensure.new(parent, position(node)) do |n|
        node.children.map {|c| transform(c, n)}
      end
    end

    def evaluate_at_start?(node)
      if node[0] =~ /Mod$/ && node[2] && node[2][0] == 'Begin'
        false
      else
        true
      end
    end

    def transform_while(node, parent)
      condition_node = node[1]
      body_node = node[2]
      Loop.new(parent, position(node), evaluate_at_start?(node), false) do |loop|
        [
          Condition.new(loop, position(condition_node)) {|cond| [transform(condition_node, cond)]},
          transform(body_node, loop)
        ]
      end
    end
    def transform_while_mod(node, parent)
      transform_while(node, parent)
    end

    def transform_until(node, parent)
      condition_node = node[1]
      body_node = node[2]
      Loop.new(parent, position(node), evaluate_at_start?(node), true) do |loop|
        [
          Condition.new(loop, position(condition_node)) {|cond| [transform(condition_node, cond)]},
          transform(body_node, loop)
        ]
      end
    end
    def transform_until_mod(node, parent)
      transform_until(node, parent)
    end

    def transform_for(node, parent)
      var_node = node[1]
      body_node = node[2]
      iter_node = node[3]
      Call.new(parent, position(node), 'each') do |each|
        [
          transformer.transform(iter_node, each),
          [],
          Block.new(each, position(body_node)) do |block|
            [
              Arguments.new(block, position(var_node)) do |args|
                [
                  # TODO support for multiple assignment?
                  [RequiredArgument.new(args,
                                        position(var_node),
                                        var_node[1])
                  ]
                ]
              end,
              transformer.transform(body_node, block)
            ]
          end
        ]
      end
    end

    def transform_rescue(node, parent)
      body_node = node[1]
      clauses = node[2]
      Rescue.new(parent, position(node)) do |node|
        [
          transformer.transform(body_node, node),
          clauses.map {|clause| transformer.transform(clause, node)}
        ]
      end
    end

    def transform_rescue_clause(node, parent)
      exceptions = node[1]
      var_name = node[2]
      name = transform(var_name, nil) unless var_name.nil? || var_name.kind_of?(::String)
      body = node[3]
      RescueClause.new(parent, position(node)) do |clause|
        clause.name = var_name if var_name
        [
          if exceptions.size == 0
            [String.new(clause, position(node), 'java.lang.Exception')]
          else
            exceptions.map {|name| Constant.new(clause, position(node), name)}
          end,
          body ? transformer.transform(body, clause) : Null.new(clause, position(node))
        ]
      end
    end

    def transform_hash(node, parent)
      Call.new(parent, position(node), 'new_hash') do |call|
        [
          Builtin.new(call, position(node)),
          [
            Array.new(call, position(node)) do |array|
              values = []
              node.children.each do |assoc|
                assoc.children.each do |child|
                  values << transform(child, array)
                end
              end
              values
            end
          ]
        ]
      end
    end

    def transform_op_assign(node, parent)
      target = node[1]
      attribute = node[2]
      op = node[3]
      value = node[4]
      temp = transformer.tmp
      tempval = transformer.tmp
      position = position(node)
      setter = "#{attribute}="
      getter = attribute
      Body.new(parent, position) do |body|
        [
          LocalAssignment.new(body, position, temp) {|l| transform(target, l)},
          LocalAssignment.new(body, position, tempval) do |l|
            Call.new(l, position, op) do |op_call|
              [
                Call.new(op_call, position, getter) do |get_call|
                  [
                    Local.new(get_call, position, temp),
                    []
                  ]
                end,
                [transform(value, op_call)],
              ]
            end
          end,
          Call.new(body, position, setter) do |set_call|
            [
              Local.new(set_call, position, temp),
              [ Local.new(set_call, position, tempval) ],
            ]
          end,
          Local.new(body, position, tempval),
        ]
      end
    end

    def transform_unquote(node, parent)
      Unquote.new(parent, position(node)) do |unquote|
        [transform(node[1], unquote)]
      end
    end

    def transform_unquote_assign(node, parent)
      name, value = node[1], node[2]
      UnquoteAssign.new(parent, position(node)) do |unquote|
        [transform(name, unquote), transform(value, unquote)]
      end
    end

    def transform_block_pass(node, parent)
      BlockPass.new(parent, position(node)) do |blockpass|
        [transform(node[1], blockpass)]
      end
    end

    def transform_annotation(node, parent)
      classname = node[1]
      values = if node[2]
        node[2].children
      else
        []
      end
      annotation = Annotation.new(parent, position(node)) do |anno|
        [String.new(anno, position(node), classname)]
      end
      values.each do |assoc|
        key = assoc[1]
        value = assoc[2]
        name = key[1]
        annotation[name] = transform(value, annotation)
      end
      transformer.add_annotation(annotation)
      return Noop.new(parent, position(node))
    end
  end
end
