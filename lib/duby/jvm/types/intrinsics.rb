require 'bitescript'
require 'duby/jvm/types/enumerable'

class BiteScript::MethodBuilder
  def op_to_bool
    done_label = label
    true_label = label

    yield(true_label)
    iconst_0
    goto(done_label)
    true_label.set!
    iconst_1
    done_label.set!
  end
end

module Duby::JVM::Types
  class Type
    def load(builder, index)
      builder.send "#{prefix}load", index
    end

    def store(builder, index)
      builder.send "#{prefix}store", index
    end

    def return(builder)
      builder.send "#{prefix}return"
    end

    def init_value(builder)
      builder.aconst_null
    end

    def intrinsics
      @intrinsics ||= begin
        @intrinsics = Hash.new {|h, k| h[k] = {}}
        add_intrinsics
        @intrinsics
      end
    end

    def add_method(name, args, method_or_type=nil, &block)
      if block_given?
        method_or_type = Intrinsic.new(self, name, args,
                                       method_or_type, &block)
      end
      intrinsics[name][args] = method_or_type
    end

    def add_macro(name, *args, &block)
      type = Duby::AST::InlineCode.new(&block)
      intrinsics[name][args] = Intrinsic.new(self, name, args, type) do
        raise "Macro should be expanded, no called!"
      end
    end

    def declared_intrinsics
      methods = []
      intrinsics.each do |name, group|
        group.each do |args, method|
          methods << method
        end
      end
      interfaces.each do |interface|
        methods.concat(interface.declared_intrinsics)
      end
      methods
    end

    def add_intrinsics
      add_method('nil?', [], Boolean) do |compiler, call, expression|
        if expression
          call.target.compile(compiler, true)
          compiler.method.op_to_bool do |target|
            compiler.method.ifnull(target)
          end
        end
      end

      add_method('==', [Object], Boolean) do |compiler, call, expression|
        # Should this call Object.equals for consistency with Ruby?
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          compiler.method.op_to_bool do |target|
            compiler.method.if_acmpeq(target)
          end
        end
      end

      add_method('!=', [Object], Boolean) do |compiler, call, expression|
        # Should this call Object.equals for consistency with Ruby?
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          compiler.method.op_to_bool do |target|
            compiler.method.if_acmpne(target)
          end
        end
      end
    end
  end

  class ArrayType
    def add_intrinsics
      super
      add_enumerable_macros

      add_method(
          '[]', [Int], component_type) do |compiler, call, expression|
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          component_type.aload(compiler.method)
        end
      end

      add_method('[]=',
                 [Int, component_type],
                 component_type) do |compiler, call, expression|
        call.target.compile(compiler, true)
        convert_args(compiler, call.parameters, [Int, component_type])
        component_type.astore(compiler.method)
        if expression
          call.parameters[1].compile(compiler, true)
        end
      end

      add_method('length', [], Int) do |compiler, call, expression|
        call.target.compile(compiler, true)
        compiler.method.arraylength
      end

      add_macro('each', Duby::AST.block_type) do |transformer, call|
        Duby::AST::Loop.new(call.parent,
                            call.position, true, false) do |forloop|
          index = transformer.tmp
          array = transformer.tmp

          init = transformer.eval("#{index} = 0;#{array} = nil")
          array_assignment = init.children[-1]
          array_assignment.value = call.target
          call.target.parent = array_assignment
          forloop.init << init

          var = call.block.args.args[0]
          if var
            forloop.pre << transformer.eval(
                "#{var.name} = #{array}[#{index}]", '', forloop, index, array)
          end
          forloop.post << transformer.eval("#{index} += 1")
          call.block.body.parent = forloop if call.block.body
          [
            Duby::AST::Condition.new(forloop, call.position) do |c|
              [transformer.eval("#{index} < #{array}.length",
                                '', forloop, index, array)]
            end,
            call.block.body
          ]
        end
      end
    end
  end

  class StringType < Type
    def add_intrinsics
      super
      add_method('+', [String], String) do |compiler, call, expression|
        if expression
          java_method('concat', String).call(compiler, call, expression)
        end
      end
      add_method('+', [Int], String) do |compiler, call, expression|
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          compiler.method.invokestatic String, "valueOf", [String, Int]
          compiler.method.invokevirtual String, "concat", [String, String]
        end
      end
      add_method('+', [Float], String) do |compiler, call, expression|
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          compiler.method.invokestatic String, "valueOf", [String, Float]
          compiler.method.invokevirtual String, "concat", [String, String]
        end
      end
    end
  end

  class IterableType < Type
    def add_intrinsics
      super
      add_enumerable_macros
      add_macro('each', Duby::AST.block_type) do |transformer, call|
        Duby::AST::Loop.new(call.parent,
                            call.position, true, false) do |forloop|
          it = transformer.tmp

          assignment = transformer.eval("#{it} = foo.iterator")
          assignment.value.target = call.target
          call.target.parent = assignment.value
          forloop.init << assignment

          var = call.block.args.args[0]
          if var
            forloop.pre << transformer.eval(
                "#{var.name} = #{it}.next", '', forloop, it)
          end
          call.block.body.parent = forloop if call.block.body
          [
            Duby::AST::Condition.new(forloop, call.position) do |c|
              [transformer.eval("#{it}.hasNext", '', forloop, it)]
            end,
            call.block.body
          ]
        end
      end
    end
  end

  class PrimitiveType
    # Primitives define their own intrinsics instead of getting the Object ones.
    def add_intrinsics
    end
  end
end