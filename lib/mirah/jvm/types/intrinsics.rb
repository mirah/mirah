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
require 'mirah/jvm/types/bitescript_ext'

module Mirah::JVM::Types
  class Type
    java_import 'org.mirah.macros.anno.MacroDef'

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

    def macros
      @macros ||= Hash.new {|h, k| h[k] = {}}
    end

    def add_method(name, args, method_or_type=nil, &block)
      if block_given?
        method_or_type = Intrinsic.new(self, name, args,
                                       method_or_type, &block)
      end
      intrinsics[name][args] = method_or_type
    end

    def add_compiled_macro(klass)
      name, arg_types, is_static = read_macrodef_annotation(klass)
      if arg_types.nil?
        return
      elsif is_static && !self.meta?
        self.meta.add_compiled_macro(klass)
        return
      end

      log "Adding macro #{self.name}.#{name}(#{arg_types.map{|t| t.full_name}.join(', ')})"
      # TODO separate static and instance macros
      macro = Macro.new(self, name, arg_types) do |call, typer|
        #TODO scope
        # We probably need to set the scope on all the parameters, plus the
        # arguments and body of any block params. Also make sure scope is copied
        # when cloned.
        scope = typer.scoper.get_scope(call)
        # call.parameters.each do |arg|
        #   arg.scope = scope
        # end
        begin
          expander = klass.constructors[0].newInstance(typer.macro_compiler, call)
          ast = expander.expand
        # rescue
        #   puts "Unable to expand macro #{name.inspect} from #{klass} with #{call}"
        end
        if ast
          body = Mirah::AST::NodeList.new(ast.position)
          # TODO scope
          # static_scope = typer.scoper.add_scope(body)
          # static_scope.parent = typer.scoper.get_scope(call)
          body.add(ast)
          # if call.target
          #   static_scope.self_type = call.target.inferred_type!
          #   static_scope.self_node = call.target
          # else
          #   static_scope.self_type = scope.self_type
          # end

          body
        else
          Mirah::AST::Noop.new
        end
      end
      macros[name][arg_types] = macro
    end

    def declared_macros(name=nil)
      result = []
      each_name = lambda do |name, hash|
        hash.each do |args, macro|
          result << macro
        end
      end
      if name
        each_name.call(name, self.macros[name])
      else
        self.macros.each &each_name
      end
      result
    end

    def macro(name, types)
      macro = macros[name][types]
      return macro if macro
      macro = superclass.macro(name, types) if (superclass && !superclass.isError)
      return macro if macro
      interfaces.each do |interface|
        macro = interface.macro(name, types) unless interface.isError
        return macro if macro
      end
      nil
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
        methods.concat(interface.declared_intrinsics(name)) unless interface.isError
      end
      methods
    end

    def load_extensions(klass=nil)
      mirror = nil
      if klass
        mirror = @type_system.mirror_class(klass)
      elsif jvm_type
        mirror = jvm_type
      end
      if mirror
        extensions = mirror.getDeclaredAnnotation('org.mirah.macros.anno.Extensions')
        return self if extensions.nil?
        macros = extensions['macros']
        return self if macros.nil?
        macros.each do |macro_class|
          klass = begin
            JRuby.runtime.jruby_class_loader.loadClass(macro_class)
          rescue java.lang.NoClassDefFoundError => ex
            raise ex
          end
          add_compiled_macro(klass)
        end
      end
      self
    end

    def read_macrodef_annotation(klass)
      macro = klass.getAnnotation(MacroDef.java_class)
      if macro.nil?
        error("Unable to load macro #{klass.name}: no MacroDef annotation")
        return
      end
      macro_name = macro.name
      # TODO optional, rest args
      args = macro.arguments.required.map do |typename|
        type = @type_system.get_type(typename)
        raise "Unable to find class #{typename}" unless type
        type
      end
      [macro_name, args, macro.is_static]
    end

    def add_intrinsics
      boolean = @type_system.type(nil, 'boolean')
      object_type = @type_system.type(nil, 'java.lang.Object')
      class_type = @type_system.type(nil, 'java.lang.Class')

      add_method('nil?', [], boolean) do |compiler, call, expression|
        if expression
          compiler.visit(call.target, true)
          compiler.method.op_to_bool do |target|
            compiler.method.ifnull(target)
          end
        end
      end

      add_method('==', [object_type], boolean) do |compiler, call, expression|
        # Should this call Object.equals for consistency with Ruby?
        if expression
          compiler.visit(call.target, true)
          compiler.visit(call.parameters(0), true)
          compiler.method.op_to_bool do |target|
            compiler.method.if_acmpeq(target)
          end
        end
      end

      add_method('!=', [object_type], boolean) do |compiler, call, expression|
        # Should this call Object.equals for consistency with Ruby?
        if expression
          compiler.visit(call.target, true)
          compiler.visit(call.parameters(0), true)
          compiler.method.op_to_bool do |target|
            compiler.method.if_acmpne(target)
          end
        end
      end

      add_method('kind_of?', [object_type.meta], boolean) do |compiler, call, expression|
        compiler.visit(call.target, expression)
        if expression
          klass = compiler.inferred_type(call.parameters(0))
          compiler.method.instanceof(klass.unmeta)
        end
      end

      # add_macro('kind_of?', class_type) do |transformer, call|
      #   klass, object = call.parameters(0), call.target
      #   Mirah::AST::Call.new(call.parent, call.position, 'isInstance') do |call2|
      #     klass.parent = object.parent = call2
      #     [
      #       klass,
      #       [object]
      #     ]
      #   end
      # end
      #
    end
  end

  class ArrayType
    begin
      java_import 'org.mirah.builtins.ArrayExtensions'
      java_import 'org.mirah.builtins.EnumerableExtensions'
    rescue NameError
      ArrayExtensions = nil
      EnumerableExtensions = nil
    end

    def add_intrinsics
      super
      load_extensions(EnumerableExtensions.java_class) if EnumerableExtensions
      load_extensions(ArrayExtensions.java_class) if ArrayExtensions
      int_type = @type_system.type(nil, 'int')
      add_method(
          '[]', [int_type], component_type) do |compiler, call, expression|
        if expression
          compiler.visit(call.target, true)
          compiler.visit(call.parameters(0), true)
          component_type.aload(compiler.method)
        end
      end

      add_method('[]=',
                 [int_type, component_type],
                 component_type) do |compiler, call, expression|
        compiler.visit(call.target, true)
        convert_args(compiler, call.parameters, [@type_system.type(nil, 'int'), component_type])
        component_type.astore(compiler.method)
        if expression
          compiler.visit(call.parameters(1), true)
        end
      end

      add_method('length', [], int_type) do |compiler, call, expression|
        compiler.visit(call.target, true)
        compiler.method.arraylength
      end
    end
  end

  class MetaType
    def add_intrinsics
      add_method('class', [], @type_system.type(nil, 'java.lang.Class')) do |compiler, call, expression|
        if expression
          compiler.method.ldc_class(unmeta)
        end
      end
      add_method('[]', [], unmeta.array_type.meta) do |compiler, call, expression|
        compiler.method.ldc_class(unmeta.array_type.meta)
      end
    end
  end

  class ArrayMetaType
    def add_intrinsics
      super
      load_extensions(@type_system.type(nil, 'org.mirah.builtins.ArrayMetaExtensions'))
      # add_macro('cast', @type_system.type(nil, 'java.lang.Object')) do |transformer, call|
      #   call.cast = true
      #   call.resolve_if(nil) { unmeta }
      #   call
      # end
    end
  end

  class StringType < Type
    def add_intrinsics
      super
      string_type = @type_system.type(nil, 'java.lang.String')
      bool_type = @type_system.type(nil, 'boolean')
      int_type = @type_system.type(nil, 'int')
      long_type = @type_system.type(nil, 'long')
      char_type = @type_system.type(nil, 'char')
      float_type = @type_system.type(nil, 'float')
      double_type = @type_system.type(nil, 'double')
      add_method('+', [string_type], string_type) do |compiler, call, expression|
        if expression
          java_method('concat', string_type).call(compiler, call, expression)
        end
      end
      add_method('+', [bool_type], string_type) do |compiler, call, expression|
        if expression
          compiler.visit(call.target, true)
          compiler.visit(call.parameters(0), true)
          compiler.method.invokestatic string_type, "valueOf", [string_type, bool_type]
          compiler.method.invokevirtual string_type, "concat", [string_type, string_type]
        end
      end
      add_method('+', [char_type], string_type) do |compiler, call, expression|
        if expression
          compiler.visit(call.target, true)
          compiler.visit(call.parameters(0), true)
          compiler.method.invokestatic string_type, "valueOf", [string_type, char_type]
          compiler.method.invokevirtual string_type, "concat", [string_type, string_type]
        end
      end
      add_method('+', [int_type], string_type) do |compiler, call, expression|
        if expression
          compiler.visit(call.target, true)
          compiler.visit(call.parameters(0), true)
          compiler.method.invokestatic string_type, "valueOf", [string_type, int_type]
          compiler.method.invokevirtual string_type, "concat", [string_type, string_type]
        end
      end
      add_method('+', [long_type], string_type) do |compiler, call, expression|
        if expression
          compiler.visit(call.target, true)
          compiler.visit(call.parameters(0), true)
          compiler.method.invokestatic string_type, "valueOf", [string_type, long_type]
          compiler.method.invokevirtual string_type, "concat", [string_type, string_type]
        end
      end
      add_method('+', [float_type], string_type) do |compiler, call, expression|
        if expression
          compiler.visit(call.target, true)
          compiler.visit(call.parameters(0), true)
          compiler.method.invokestatic string_type, "valueOf", [string_type, float_type]
          compiler.method.invokevirtual string_type, "concat", [string_type, string_type]
        end
      end
      add_method('+', [double_type], string_type) do |compiler, call, expression|
        if expression
          compiler.visit(call.target, true)
          compiler.visit(call.parameters(0), true)
          compiler.method.invokestatic string_type, "valueOf", [string_type, double_type]
          compiler.method.invokevirtual string_type, "concat", [string_type, string_type]
        end
      end
      add_method('[]', [int_type], char_type) do |compiler, call, expression|
        if expression
          compiler.visit(call.target, true)
          compiler.visit(call.parameters(0), true)
          compiler.method.invokevirtual string_type, "charAt", [char_type, int_type]
        end
      end
      add_method('[]', [int_type, int_type], string_type) do |compiler, call, expression|
        if expression
          compiler.visit(call.target, true)
          compiler.visit(call.parameters(0), true)
          compiler.method.dup
          compiler.visit(call.parameters[1], true)
          compiler.method.iadd
          compiler.method.invokevirtual string_type, "substring", [string_type, int_type, int_type]
        end
      end
    end
  end

  class IterableType < Type
    def add_intrinsics
      super
      return
      add_enumerable_macros
      add_macro('each', @type_system.block_type) do |transformer, call|
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
