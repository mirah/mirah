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

require 'bitescript'
require 'mirah/jvm/types/enumerable'

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

module Mirah::JVM::Types
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
      type = Mirah::AST::InlineCode.new(&block)
      intrinsics[name][args] = Intrinsic.new(self, name, args, type) do
        raise "Macro should be expanded, no called!"
      end
    end

    def add_compiled_macro(klass, name, arg_types)
      add_macro(name, *arg_types) do |duby, call|
        # Ick. We need to preserve the scope of the arguments to the macro.
        # However the only way to do that is to wrap them in a ScopedBody.
        # It'd be better if we didn't have to expose this wrapper node to
        # the user code.
        #
        if call.block && call.name != 'quote'
          call.block.body = wrap_with_scoped_body call, call.block.body
        end
        
        call.parameters = call.parameters.map do |arg|
          wrap_with_scoped_body call, arg
        end
        
        expander = klass.constructors[0].newInstance(duby, call)
        ast = expander.expand
        if ast
          body = Mirah::AST::ScopedBody.new(call.parent, call.position)
          body << ast
          if call.target
            body.static_scope.self_type = call.target.inferred_type!
            body.static_scope.self_node = call.target
          end
          body
        else
          Mirah::AST::Noop.new(call.parent, call.position)
        end
      end
    end
    
    def wrap_with_scoped_body call, node
      wrapper = Mirah::AST::ScopedBody.new(call.parent, call.position)
      wrapper.static_scope = call.scope.static_scope
      wrapper << node
    end

    def declared_intrinsics(name=nil)
      methods = []
      all_intrinsics = if name.nil?
        intrinsics
      else
        [[name, intrinsics[name]]]
      end
      all_intrinsics.each do |name, group|
        group.each do |args, method|
          methods << method
        end
      end
      interfaces.each do |interface|
        methods.concat(interface.declared_intrinsics(name))
      end
      methods
    end

    def load_extensions(klass=nil)
      mirror = nil
      if klass
        factory = Mirah::AST.type_factory
        mirror = factory.get_mirror(klass.getName)
      elsif jvm_type
        mirror = jvm_type
      end
      if mirror
        extensions = mirror.getDeclaredAnnotation('duby.anno.Extensions')
        return self if extensions.nil?
        macros = extensions['macros']
        return self if macros.nil?
        macros.each do |macro|
          macro_name = macro['name']
          class_name = macro['class']
          types = BiteScript::ASM::Type.get_argument_types(macro['signature'])
          args = types.map do |type|
            if type.class_name == 'duby.lang.compiler.Block'
              Mirah::AST::TypeReference::BlockType
            else
              Mirah::AST.type(nil, type)
            end
          end
          klass = JRuby.runtime.jruby_class_loader.loadClass(class_name)
          add_compiled_macro(klass, macro_name, args)
        end
      end
      self
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

      add_macro('kind_of?', ClassType) do |transformer, call|
        klass, object = call.parameters[0], call.target
        Mirah::AST::Call.new(call.parent, call.position, 'isInstance') do |call2|
          klass.parent = object.parent = call2
          [
            klass,
            [object]
          ]
        end
      end

      add_method('kind_of?', [Object.meta], Boolean) do |compiler, call, expression|
        call.target.compile(compiler, expression)
        if expression
          klass = call.parameters[0].inferred_type!
          compiler.method.instanceof(klass.unmeta)
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

      add_macro('each', Mirah::AST.block_type) do |transformer, call|
        Mirah::AST::Loop.new(call.parent,
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
            Mirah::AST::Condition.new(forloop, call.position) do |c|
              [transformer.eval("#{index} < #{array}.length",
                                '', forloop, index, array)]
            end,
            call.block.body
          ]
        end
      end
    end
  end

  class MetaType
    def add_intrinsics
      add_method('class', [], ClassType) do |compiler, call, expression|
        if expression
          compiler.method.ldc_class(unmeta)
        end
      end
    end
  end

  class ArrayMetaType
    def add_intrinsics
      super
      add_macro('cast', Object) do |transformer, call|
        call.cast = true
        call.resolve_if(nil) { unmeta }
        call
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
      add_method('+', [Boolean], String) do |compiler, call, expression|
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          compiler.method.invokestatic String, "valueOf", [String, Boolean]
          compiler.method.invokevirtual String, "concat", [String, String]
        end
      end
      add_method('+', [Char], String) do |compiler, call, expression|
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          compiler.method.invokestatic String, "valueOf", [String, Char]
          compiler.method.invokevirtual String, "concat", [String, String]
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
      add_method('+', [Long], String) do |compiler, call, expression|
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          compiler.method.invokestatic String, "valueOf", [String, Long]
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
      add_method('+', [Double], String) do |compiler, call, expression|
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          compiler.method.invokestatic String, "valueOf", [String, Double]
          compiler.method.invokevirtual String, "concat", [String, String]
        end
      end
      add_method('[]', [Int], Char) do |compiler, call, expression|
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          compiler.method.invokevirtual String, "charAt", [Char, Int]
        end
      end
      add_method('[]', [Int, Int], String) do |compiler, call, expression|
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          compiler.method.dup
          call.parameters[1].compile(compiler, true)
          compiler.method.iadd
          compiler.method.invokevirtual String, "substring", [String, Int, Int]
        end
      end
    end
  end

  class IterableType < Type
    def add_intrinsics
      super
      add_enumerable_macros
      add_macro('each', Mirah::AST.block_type) do |transformer, call|
        Mirah::AST::Loop.new(call.parent,
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
          else
            forloop.pre << transformer.eval("#{it}.next", '', forloop, it)
          end
          call.block.body.parent = forloop if call.block.body
          [
            Mirah::AST::Condition.new(forloop, call.position) do |c|
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