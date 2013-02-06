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

require 'mirah/jvm/types'

class Java::JavaMethod
  def static?
    java.lang.reflect.Modifier.static?(modifiers)
  end

  def abstract?
    java.lang.reflect.Modifier.abstract?(modifiers)
  end
end

module Mirah::JVM::Types
  AST ||= Mirah::AST

  module ArgumentConversion
    def convert_args(compiler, values, types=nil)
      # TODO boxing/unboxing
      types ||= argument_types
      needs_to_build_varargs_array = false
      
      if respond_to?(:varargs?) && varargs?
        non_varargs_types = types[0..-2]
        non_varargs_values = values.first non_varargs_types.size

        varargs_values = values.to_a.last(values.size - non_varargs_values.size)
        varargs_type = types.last

        unless varargs_values.length == 1 &&
          varargs_type.compatible?(compiler.inferred_type(varargs_values.first))
          needs_to_build_varargs_array = true
          values = non_varargs_values
        end
      end

      values_and_types = values.zip(types)
      
      
      values_and_types.each do |value, type|
        compiler.visit(value, true)
        if type.primitive? && type != compiler.inferred_type(value)
          compiler.inferred_type(value).compile_widen(compiler.method, type)
        end
      end

      if needs_to_build_varargs_array
        compiler.visitVarargsArray(varargs_type, varargs_values)
      end
    end
  end

  Type.send :include, ArgumentConversion

  class Intrinsic
    include ArgumentConversion
    attr_reader :name, :argument_types, :return_type

    def initialize(klass, name, args, type, &block)
      raise ArgumentError, "Block required" unless block_given?
      @class = klass
      @name = name
      @argument_types = args
      @return_type = type
      @block = block
    end

    def call(builder, ast, expression, *args)
      @block.call(builder, ast, expression, *args)
    end

    def declaring_class
      @class
    end

    def constructor?
      false
    end

    def field?
      false
    end

    def abstract?
      false
    end

    def exceptions
      []
    end

    def varargs?
      false
    end
  end

  class Macro
    java_import 'org.mirah.typer.InlineCode'
    java_import 'org.mirah.typer.NodeBuilder'
    attr_reader :name, :argument_types, :return_type

    def initialize(klass, name, args, &block)
      raise ArgumentError, "Block required" unless block_given?
      @class = klass
      @name = name
      @argument_types = args
      raise ArgumentError unless args.all?
      @return_type = InlineCode.new(block.to_java(NodeBuilder))
    end

    def declaring_class
      @class
    end
  end

  class JavaCallable
    include ArgumentConversion
    java_import 'org.mirah.typer.ResolvedType'
    java_import 'org.mirah.typer.TypeSystem'

    attr_accessor :member

    def initialize(types, member)
      raise ArgumentError unless types.kind_of?(TypeSystem)
      @types = types
      @member = member
    end

    def name
      @name ||= @member.name
    end

    def field?
      false
    end

    def parameter_types
      @member.parameter_types
    end
  end

  class JavaConstructor < JavaCallable
    def argument_types
      @argument_types ||= @member.argument_types.map do |arg|
        if arg.kind_of?(Type) || arg.nil?
          arg
        else
          @types.type(nil, arg)
        end
      end
    end

    def return_type
      declaring_class
    end

    def exceptions
      @member.exception_types.map do |exception|
        if exception.kind_of?(ResolvedType)
          exception
        else
          @types.type(nil, exception.class_name)
        end
      end
    end

    def declaring_class
      @types.type(nil, @member.declaring_class)
    end

    def type_parameters
      @declaring_class and @declaring_class.jvm_type.type_parameters
    end

    def call(compiler, ast, expression, parameters=nil, delegate=false)
      target = compiler.inferred_type(ast.target)
      unless delegate
        compiler.method.new target
        compiler.method.dup if expression
      end
      parameters ||= ast.parameters
      convert_args(compiler, parameters)
      compiler.method.invokespecial(
        target,
        "<init>",
        [nil, *@member.argument_types])
    end

    def constructor?
      true
    end

    def varargs?
      @member.varargs?
    end

  end

  class JavaMethod < JavaConstructor
    def return_type
      @return_type ||= begin
        if void?
          @types.type(nil, 'void')
        else
          @types.type(nil, @member.return_type)
        end
      end
    end

    def static?
      @member.static?
    end

    def abstract?
      @member.abstract?
    end

    def type_parameters
      @member.type_parameters
    end

    def void?
      return_type = @member.return_type
      return true if return_type.nil?
      if return_type.respond_to?(:descriptor) && return_type.descriptor == 'V'
        return true
      end
      false
    end

    def constructor?
      false
    end

    def call(compiler, ast, expression, parameters=nil)
      target = compiler.inferred_type(ast.target)
      compiler.visit(ast.target, true)

      # if expression, void methods return the called object,
      # for consistency and chaining
      # TODO: inference phase needs to track that signature is
      # void but actual type is callee
      if expression && void?
        compiler.method.dup
      end

      parameters ||= ast.parameters
      convert_args(compiler, parameters)
      if target.interface?
        compiler.method.invokeinterface(
          target,
          name,
          [@member.return_type, *@member.argument_types])
      else
        compiler.method.invokevirtual(
          target,
          name,
          [@member.return_type, *@member.argument_types])
      end

      if expression && !void?
        # Insert a cast if the inferred type and actual type differ. This is part of generics support.
        inferred_return_type = compiler.inferred_type(ast)
        if !inferred_return_type.assignableFrom(return_type)
          compiler.method.checkcast(inferred_return_type)
        end
      end

      unless expression || void?
        return_type.pop(compiler.method)
      end
    end

    def call_special(compiler, target, target_type, parameters, expression)
      target_type ||= compiler.inferred_type(target)
      compiler.visit(target, true)

      # if expression, void methods return the called object,
      # for consistency and chaining
      # TODO: inference phase needs to track that signature is
      # void but actual type is callee
      if expression && void?
        compiler.method.dup
      end

      convert_args(compiler, parameters)
      if target_type.interface?
        raise "interfaces should not receive call_special"
      else
        compiler.method.invokespecial(
          target_type,
          name,
          [@member.return_type, *@member.argument_types])
      end

      unless expression || void?
        return_type.pop(compiler.method)
      end
    end
  end

  class JavaStaticMethod < JavaMethod
    def call(compiler, ast, expression, parameters=nil)
      target = declaring_class
      parameters ||= ast.parameters
      convert_args(compiler, parameters)
      compiler.method.invokestatic(
        target,
        name,
        [@member.return_type, *@member.argument_types])
      # if expression, void static methods return null, for consistency
      # TODO: inference phase needs to track that signature is void
      # but actual type is null object
      compiler.method.aconst_null if expression && void?
      return_type.pop(compiler.method) unless expression || void?
    end
  end

  class JavaDynamicMethod < JavaMethod
    def initialize(type_system, name, *argument_types)
      super(type_system, nil)
      @name = name
      @argument_types = argument_types
    end

    def return_type
      @types.type(nil, 'dynamic')
    end

    def declaring_class
      java.lang.Object
    end

    def argument_types
      @argument_types
    end

    def call(compiler, ast, expression, parameters=nil)
      target = compiler.inferred_type(ast.target)
      compiler.visit(ast.target, true)

      parameters ||= ast.parameters
      parameters.each do |param|
        compiler.visit(param, true)
      end
      handle = compiler.method.mh_invokestatic(
        org.dynalang.dynalink.DefaultBootstrapper,
        "bootstrap",
        java.lang.invoke.CallSite,
        java.lang.invoke.MethodHandles::Lookup,
        java.lang.String,
        java.lang.invoke.MethodType)
      compiler.method.invokedynamic(
        "dyn:callPropWithThis:#{name}",
        [return_type, target, *@argument_types],
        handle)

      unless expression
        return_type.pop(compiler.method)
      end
    end
  end

  class JavaFieldAccessor < JavaMethod
    def field?
      true
    end

    def return_type
      @types.type(nil, @member.type)
    end

    def public?
      @member.public?
    end

    def final?
      @member.final?
    end
  end

  class JavaFieldGetter < JavaFieldAccessor
    def argument_types
      []
    end

    def call(compiler, ast, expression, parameters=nil)
      target = compiler.inferred_type(ast.target)

      # TODO: assert that no args are being passed, though that should have failed lookup

      if expression
        if @member.static?
          compiler.method.getstatic(target, name, @member.type)
        else
          compiler.visit(ast.target, true)
          compiler.method.getfield(target, name, @member.type)
        end
      end
    end
  end

  class JavaFieldSetter < JavaFieldAccessor
    def return_type
      @types.type(nil, @member.type)
    end

    def argument_types
      [@types.type(nil, @member.type)]
    end

    def call(compiler, ast, expression, parameters=nil)
      target = compiler.inferred_type(ast.target)

      # TODO: assert that no args are being passed, though that should have failed lookup

      parameters ||= ast.parameters
      if @member.static?
        convert_args(compiler, parameters)
        compiler.method.dup if expression
        compiler.method.putstatic(target, name, @member.type)
      else
        compiler.visit(ast.target, true)
        convert_args(compiler, parameters)
        compiler.method.dup_x2 if expression
        compiler.method.putfield(target, name, @member.type)
      end
    end
  end

  class MirahMember
    attr_reader :name, :argument_types, :declaring_class, :return_type
    attr_reader :exception_types

    def initialize(klass, name, args, return_type, static, exceptions)
      if return_type.name == 'void' || return_type.name == ':unreachable'
        return_type = nil
      end
      @declaring_class = klass
      @name = name
      @argument_types = args
      @return_type = return_type
      @static = static
      @exception_types = exceptions || []
    end

    def static?
      @static
    end

    def abstract?
      @declaring_class.interface?
    end

    def varargs?
      false
    end
  end

  class Type
    def method_listeners
      if meta?
        unmeta.method_listeners
      else
        @method_listeners ||= {}
      end
    end

    def method_updated(name)
      listeners = method_listeners[name]
      listeners.values.each do |l|
        if l.kind_of?(Proc)
          l.call(name)
        else
          l.method_updated(name)
        end
      end if listeners
    end

    def add_method_listener(name, listener=nil, &block)
      listeners = method_listeners[name] ||= {}
      if listener
        unless listener.respond_to?(:method_updated) || listener.kind_of?(Proc)
          raise "Invalid listener"
        end
        listeners[listener] = listener
      else
        listeners[block] = block
      end
      if !self.meta? && jvm_type && superclass && !superclass.isError
        superclass.add_method_listener(name, self)
      end
      interfaces.each {|i| i.add_method_listener(name, self) unless i.isError}
    end

    # TODO take a scope and check visibility
    def find_callable_macros(name)
      interfaces = []
      macros = find_callable_macros2(name, interfaces)
      seen = {}
      until interfaces.empty?
        interface = interfaces.pop
        next if seen[interface] || interface.isError
        seen[interface] = true
        interfaces.concat(interface.interfaces)
        macros.concat(interface.declared_macros(name))
      end
      macros
    end

    def find_callable_macros2(name, interfaces)
      macros = []
      interfaces.concat(self.interfaces)
      macros.concat(declared_macros(name))
      if superclass && !superclass.error?
        macros.concat(superclass.find_callable_macros2(name, interfaces))
      end
      macros
    end

    # TODO take a scope and check visibility
    def find_callable_methods(name, include_interfaces=false, &proc)
      if block_given?
        add_method_listener(name) {proc.call(find_callable_methods(name))}
        proc.call(find_callable_methods(name))
        return
      end
      interfaces = if self.interface? || include_interfaces # TODO || self.abstract?
        []
      else
        nil
      end
      methods = find_callable_methods2(name, interfaces)
      if interfaces
        seen = {}
        until interfaces.empty?
          interface = interfaces.pop
          next if seen[interface]
          seen[interface] = true
          interfaces.concat(interface.interfaces)
          methods.concat(interface.declared_instance_methods(name))
        end
      end
      methods
    end

    def find_callable_methods2(name, interfaces)
      methods = []
      interfaces.concat(self.interfaces) if interfaces
      methods.concat(declared_instance_methods(name))
      if superclass && !superclass.error?
        methods.concat(superclass.find_callable_methods2(name, interfaces))
      end
      methods
    end

    def get_method(name, args)
      method = find_method(self, name, args, nil, meta?)
      unless method
        # Allow constant narrowing for assignment methods
        if name =~ /=$/ && args[-1].respond_to?(:narrow!)
          if args[-1].narrow!
            method = find_method(self, name, args, meta?)
          end
        end
      end
      method
    end

    def constructor(*types)
      begin
        descriptors = types.map {|type| BiteScript::Signature.class_id(type)}
        constructor = jvm_type.getConstructor(*descriptors)
        return JavaConstructor.new(@type_system, constructor) if constructor
      rescue => ex
        log("#{ex.message}\n#{ex.backtrace.join("\n")}")
      end
      raise NameError, "No constructor #{name}(#{types.join ', '})"
    end

    def java_method(name, *types)
      intrinsic = intrinsics[name][types]
      return intrinsic if intrinsic
      jvm_types = types.map {|type| type.jvm_type}

      return JavaDynamicMethod.new(@type_system, name, *jvm_types) if dynamic?

      begin
        descriptors = types.map {|type| BiteScript::Signature.class_id(type)}
        method = jvm_type.getDeclaredMethod(name, *descriptors) if jvm_type

        if method.nil? && superclass
          method = superclass.java_method(name, *types) rescue nil
        end

        if method.nil? && jvm_type && jvm_type.abstract?
          interfaces.each do |interface|
            method = interface.java_method(name, *types) rescue nil
            break if method
          end
        end

        return method if method.kind_of?(JavaCallable)
        if method && method.static? == meta?
          return JavaStaticMethod.new(@type_system, method) if method.static?
          return JavaMethod.new(@type_system, method)
        end
      rescue   => ex
        log("#{ex.message}\n#{ex.backtrace.join("\n")}")
      end
      raise NameError, "No method #{self.name}.#{name}(#{types.join ', '})"
    end

    def declared_instance_methods(name=nil)
      methods = []
      if jvm_type && !array?
        jvm_type.getDeclaredMethods(name).each do |method|
          methods << JavaMethod.new(@type_system, method) unless method.static?
        end
      end
      methods.concat((meta? ? unmeta : self).declared_intrinsics(name))
    end

    def declared_class_methods(name=nil)
      methods = []
      if jvm_type && !unmeta.array?
        jvm_type.getDeclaredMethods(name).each do |method|
          methods << JavaStaticMethod.new(@type_system, method) if method.static?
        end
      end
      methods.concat(meta.declared_intrinsics(name))
    end

    def declared_constructors
      jvm_type.getConstructors.map do |method|
        JavaConstructor.new(@type_system, method)
      end
    end

    def field_getter(name)
      if jvm_type
        field = jvm_type.getField(name)
        JavaFieldGetter.new(@type_system, field) if field
      else
        nil
      end
    end

    def field_setter(name)
      if jvm_type
        field = jvm_type.getField(name)
        JavaFieldSetter.new(@type_system, field) if field
      else
        nil
      end
    end

    def inner_class_getter(name)
      full_name = "#{self.name}$#{name}"
      inner_class = nil  # @type_system.type(nil, full_name) rescue nil
      return unless inner_class
      inner_class.inner_class = true
      add_macro(name) do |transformer, call|
        Mirah::AST::Constant.new(call.parent, call.position, full_name)
      end
      intrinsics[name][[]]
    end
  end

  class TypeDefinition
    def java_method(name, *types)
      method = instance_methods[name].find {|m| m.argument_types == types}
      return method if method
      intrinsic = intrinsics[name][types]
      return intrinsic if intrinsic
      raise NameError, "No method #{self.name}.#{name}(#{types.join ', '})"
    end

    def java_static_method(name, *types)
      method = static_methods[name].find {|m| m.argument_types == types}
      return method if method
      intrinsic = meta.intrinsics[name][types]
      return intrinsic if intrinsic
      raise NameError, "No method #{self.name}.#{name}(#{types.join ', '})"
    end

    def constructor(*types)
      constructor = constructors.find {|c| c.argument_types == types}
      return constructor if constructor
      raise NameError, "No constructor #{name}(#{types.join ', '})"
    end

    def declared_instance_methods(name=nil)
      declared_intrinsics(name) + if name.nil?
        instance_methods.values.flatten
      else
        instance_methods[name]
      end
    end

    def declared_class_methods(name=nil)
      meta.declared_intrinsics(name) + if name.nil?
        static_methods.values.flatten
      else
        static_methods[name]
      end
    end

    def declared_constructors
      constructors
    end

    def constructors
      if @constructors.nil?
        @constructors = []
        declare_method('initialize', [], self, [])
        @have_default_constructor = true
      end
      @constructors
    end

    def instance_methods
      @instance_methods ||= Hash.new {|h, k| h[k] = []}
    end

    def static_methods
      @static_methods ||= Hash.new {|h, k| h[k] = []}
    end

    def declare_method(name, arguments, type, exceptions)
      raise "Bad args" unless arguments.all?
      if type.isError
        instance_methods.delete(name)
        method_updated(name)
        return
      end
      member = MirahMember.new(self, name, arguments, type, false, exceptions)
      if name == 'initialize'
        # The ordering is important here:
        # The first call to constructors initializes @have_default_constructor.
        if constructors.size == 1 && @have_default_constructor
          constructors.clear
          @have_default_constructor = false
        elsif constructors.size > 1 && @have_default_constructor
          raise "Invalid state: default constructor but #{constructors.size} constructors"
        end
        constructors << JavaConstructor.new(@type_system, member)
      else
        instance_methods[name] << JavaMethod.new(@type_system, member)
      end
      method_updated(name)
    end

    def declare_static_method(name, arguments, type, exceptions)
      if type.isError
        static_methods.delete(name)
      else
        member = MirahMember.new(self, name, arguments, type, true, exceptions)
        static_methods[name] << JavaStaticMethod.new(@type_system, member)
      end
      method_updated(name)
    end

    def interface?
      false
    end

    def field_getter(name)
      nil
    end

    def field_setter(name)
      nil
    end
  end

  class TypeDefMeta
    def constructor(*args)
      unmeta.constructor(*args)
    end

    def java_method(*args)
      unmeta.java_static_method(*args)
    end

    def declared_class_methods(name=nil)
      unmeta.declared_class_methods(name)
    end

    def declared_instance_methods(name=nil)
      unmeta.declared_instance_methods(name)
    end

    def field_getter(name)
      nil
    end

    def field_setter(name)
      nil
    end
  end
end
