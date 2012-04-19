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

require 'jruby'
require 'mirah/jvm/types/source_mirror'
module Mirah::JVM::Types
  java_import 'org.mirah.typer.simple.SimpleTypes'
  class TypeFactory < SimpleTypes
    java_import 'org.mirah.typer.AssignableTypeFuture'
    java_import 'org.mirah.typer.PickFirst'
    java_import 'org.mirah.typer.BaseTypeFuture'
    #java_import 'org.mirah.typer.BlockType'
    java_import 'org.mirah.typer.ErrorType'
    java_import 'org.mirah.typer.MethodFuture'
    java_import 'org.mirah.typer.MethodType'
    java_import 'org.mirah.typer.TypeFuture'
    java_import 'org.mirah.typer.TypeSystem'
    java_import 'mirah.lang.ast.ClassDefinition'
    java_import 'mirah.lang.ast.InterfaceDeclaration'
    java_import 'mirah.lang.ast.Script'
    java_import 'mirah.lang.ast.SimpleString'
    include TypeSystem
    include Mirah::Logging::Logged
    
    begin
      java_import 'org.mirah.builtins.Builtins'
    rescue NameError
      puts File.dirname(__FILE__) + '/../../../../javalib/mirah-builtins.jar'
      $CLASSPATH << File.dirname(__FILE__) + '/../../../../javalib/mirah-builtins.jar'
      begin
        java_import 'org.mirah.builtins.Builtins'
      rescue NameError
        # We might be trying to compile mirah-builtins.jar, so just continue.
        Builtins = nil
      end
    end

    attr_accessor :package
    attr_reader :known_types

    class ParanoidHash < Hash
      def []=(k, v)
        raise ArgumentError, "Can't store nil for key #{k.inspect}" if v.nil?
        super(k, v)
      end
    end

    def initialize
      super(":unused")
      @known_types = ParanoidHash.new
      @anonymous_classes = Hash.new {|h, k| h[k] = 0}
      @declarations = []
      @mirrors = {}
      @futures = {}
      create_basic_types
    end

    def initialize_copy(other)
      @known_types = other.known_types.dup
      @known_types.delete_if do |key, value|
        value.basic_type.kind_of?(Mirah::JVM::Types::TypeDefinition)
      end
      @declarations = []
      @futures = {}
    end

    def maybe_initialize_builtins(compiler)
      if Builtins
        begin
          Builtins.initialize_builtins(compiler)
        rescue NativeException => ex
          log("Error initializing builtins", ex.cause)
        rescue => ex
          log("Error initializing builtins: #{ex.backtrace.join("\n")}")
        end
      else
        warning "Unable to initialize builtins"
      end
    end

    def wrap(resolved_type)
      future = BaseTypeFuture.new(nil)
      future.resolved(resolved_type) if resolved_type
      future
    end

    def cache_and_wrap(resolved_type)
      @futures[resolved_type.name] ||= wrap(resolved_type)
    end
    def cache_and_wrap_type(name)
      @futures[name] ||= begin
        type = type(nil, name)
        wrapper = wrap(type)
        wrapper.resolved(ErrorType.new([["Cannot find class #{name}"]])) if type.nil?
        wrapper
      end
    end

    # TypeSystem methods
    def addDefaultImports(scope)
      scope.import('java.lang.*', '*')
    end
    def getNullType; cache_and_wrap_type('null') end
    def getImplicitNilType; cache_and_wrap_type('implicit_nil') end
    def getVoidType; cache_and_wrap_type('void') end
    def getBaseExceptionType; cache_and_wrap_type('java.lang.Throwable') end
    def getDefaultExceptionType; cache_and_wrap_type('java.lang.Exception') end
    def getHashType; cache_and_wrap_type('java.util.HashMap') end
    def getRegexType; cache_and_wrap_type('java.util.regex.Pattern') end
    def getStringType; cache_and_wrap_type('java.lang.String') end
    def getBooleanType; cache_and_wrap_type('boolean') end
    # TODO narrowing
    def getFixnumType(value)
      long = java.lang.Long.new(value)
      if long.int_value != value
        cache_and_wrap_type('long')
      else
        cache_and_wrap_type('int')
      end
    end
    def getCharType(value) cache_and_wrap_type('char') end
    def getFloatType(value); cache_and_wrap_type('double') end
    def getMetaType(type)
      if type.kind_of?(Type)
        type.meta
      else
        future = BaseTypeFuture.new(nil)
        type.on_update {|_, resolved| future.resolved(resolved.meta)}
        future.position_set(type.position)
        future.error_message_set(type.error_message)
        future
      end
    end
    def getSuperClass(future)
      superclass = BaseTypeFuture.new(nil)
      future.on_update do |_, type|
        superclass.resolved(type.superclass)
      end
      superclass
    end
    def getArrayType(type)
      if type.kind_of?(Type)
        type.array_type
      else
        future = BaseTypeFuture.new(nil)
        type.on_update {|_, resolved| future.resolved(resolved.array_type)}
        future
      end
    end
    def getArrayLiteralType(type)
      return cache_and_wrap_type('java.util.List')
    end
    def get(scope, typeref)
      basic_type = if scope.nil?
        cache_and_wrap_type(typeref.name)
      else
        imports = scope.imports
        name = typeref.name
        name = imports[name] while imports.include?(name)
        types = [ cache_and_wrap_type(name), nil ]
        packages = []
        packages << scope.package if scope.package && scope.package != ''
        (packages + scope.search_packages).each do |package|
          types << cache_and_wrap_type("#{package}.#{name}")
          types << nil
        end

        future = PickFirst.new(types, nil)
        future.position_set(typeref.position)
        future.error_message_set("Cannot find class #{typeref.name}")
        future
      end
      if typeref.isArray
        getArrayType(basic_type)
      elsif typeref.isStatic
        getMetaType(basic_type)
      else
        basic_type
      end
    end
    def getLocalType(scope, name, position)
      scope.local_type(name, position)
    end

    def getMethodType(call)
      target = call.resolved_target
      argTypes = call.resolved_parameters
      macro_types = call.parameter_nodes.map do |node|
        get_type(node.java_class.name)
      end if call.parameter_nodes
      _find_method_type(target, call.name, argTypes, macro_types, call.position)
    end

    def _find_method_type(target, name, argTypes, macroTypes, position)
      if target.respond_to?(:isError) && target.isError
        return target
      end
      type = BaseTypeFuture.new(nil)
      target.find_method2(target, name, argTypes, macroTypes, target.meta?) do |method|
        if method.nil?
          type.resolved(ErrorType.new([
              ["Cannot find %s method %s(%s) on %s" %
                  [ target.meta? ? "static" : "instance",
                    name,
                    argTypes.map{|t| t.full_name}.join(', '),
                    target.full_name], position]]))
        elsif method.kind_of?(Exception)
          type.resolved(ErrorType.new([[method.message, position]]))
        else
          result = method.return_type
          argTypes = method.argument_types
          if result.kind_of?(TypeFuture)
            if result.isResolved
              type.resolved(result.resolve)
            else
              result.onUpdate {|x, resolved| type.resolved(resolved) }
            end
          else
            type.resolved(result)
          end
        end
      end
      argTypes = argTypes.map do |t|
        if t.isBlock
          type.position_set(position) if (position && type.position.nil?)
          # This should only happen if type is an error.
          type.resolve
        else
          t
        end
      end
      result = getMethodTypeInternal(target, name, argTypes, position)
      result.return_type.assign(type, position)
      result
    end
    def getMethodDefType(target, name, argTypes)
      if target.nil?
        return ErrorType.new([["No target"]])
      end
      args = argTypes.map {|a| a.resolve}
      target = target.resolve
      type = _find_method_type(target, name, args, nil, nil)
      type.onUpdate do |m, resolved|
        resolved = resolved.returnType if resolved.respond_to?(:returnType)
        log "Learned {0} method {1}.{2}({3}) = {4}", [
                target.meta? ? "static" : "instance",
                target.full_name,
                name,
                args.map{|a| a.full_name}.join(', '),
                resolved.full_name].to_java
        rewritten_name = name.sub(/=$/, '_set')
        if target.meta?
          target.unmeta.declare_static_method(rewritten_name, args, resolved, [])
        else
          target.declare_method(rewritten_name, args, resolved, [])
        end
      end
      if type.kind_of?(ErrorType)
        puts "Got error type for method #{name} on #{target.resolve} (#{target.resolve.class})"
      end
      type
    end
    def getMainType(scope, script)
      filename = File.basename(script.position.source.name || 'DashE')
      classname = Mirah::JVM::Compiler::JVMBytecode.classname_from_filename(filename)
      getMetaType(cache_and_wrap(declare_type(scope, classname)))
    end
    def defineType(scope, node, name, superclass, interfaces)
      # TODO what if superclass or interfaces change later?
      type = define_type(scope, node)
      future = @futures[type.name]
      if future
        future.resolved(type)
        future
      else
        cache_and_wrap(type)
      end
    end

    def addMacro(klass, name, arguments, macro)
      klass.unmeta.add_compiled_macro(macro, name, arguments)
    end
    def extendClass(classname, extensions)
      get_type(classname).load_extensions(extensions)
    end

    def define_types(builder)
      @declarations.each do |declaration|
        declaration.define(builder)
      end
    end

    def type(scope, name, array=false, meta=false)
      if name.kind_of?(BiteScript::ASM::Type)
        if name.getDescriptor[0] == ?[
          return type(scope, name.getElementType, true, meta)
        else
          name = name.getClassName
        end
      elsif name.kind_of?(Type) && name.array?
        array = true
      end
      type = basic_type(scope, name)
      type = type.array_type if type && array
      type = type.meta if type && meta
      return type
    end

    def basic_type(scope, name)
      if name.kind_of?(Type) || name.kind_of?(NarrowingType)
        return name.basic_type
      end
      orig = name
      if name.kind_of? Java::JavaClass
        if name.array?
          return type(name.component_type, true)
        else
          name = name.name
        end
      elsif name.respond_to? :java_class
        name = name.java_class.name
      end
      name = name.to_s unless name.kind_of?(::String)
      raise ArgumentError, "Bad Type #{orig}" if name =~ /Java::/
      raise ArgumentError, "Bad Type #{orig.inspect}" if name == '' || name.nil?
      find_type(scope, name)
    end

    def find_type(scope, name)
      type = get_type(name)
      return type if type

      if scope
        imports = scope.imports
        if imports.include?(name)
          name = imports[name] while imports.include?(name)
          type = get_type(name)
          return type if type
        end

        # TODO support inner class names
        if name !~ /\./
          return package_search(name, scope)
        end
      end
      return nil
    end

    def package_search(name, scope)
      packages = []
      current_package = scope.package
      packages << current_package unless current_package.nil? || current_package.empty?
      packages.concat(scope.search_packages)
      packages << 'java.lang'
      packages.each do |package|
        type =  get_type("#{package}.#{name}")
        return type if type
      end
      return nil
    end

    def getBlockType
      @block_type ||= BlockType.new
    end

    def get_type(full_name)
      type = @known_types[full_name]
      return type.basic_type if type
      mirror = get_mirror(full_name)
      unless mirror
        if full_name =~ /^(.+)\.([^.]+)/
          outer_name = $1
          inner_name = $2
          outer_type = get_type(outer_name)
          return nil if outer_type.nil?
          full_name = "#{outer_type.name}$#{inner_name}"
          mirror = get_mirror(full_name)
          return nil if mirror.nil?
        else
          return nil
        end
      end
      type = Type.new(self, mirror).load_extensions
      if full_name.include? '$'
        @known_types[full_name.gsub('$', '.')] = type
      end
      @known_types[full_name] = type
    end

    def known_type(scope, name)
      basic_type(scope, name)
    end

    def declare_type(scope, name)
      full_name = name
      package = scope.package
      if !name.include?('.')
        if package && !package.empty?
          full_name = "#{package}.#{name}"
        else
          scope.on_package_change do
            full_name = "#{scope.package}.#{name}"
            scope.import(full_name, name)
            @known_types[full_name] = @known_types[name]
          end
        end
      end
      if @known_types.include? full_name
        @known_types[full_name]
      else
        scope.import(full_name, name)
        @known_types[full_name] = TypeDefinition.new(self, scope, full_name, nil)
      end
    end

    def define_type(scope, node)
      if node.name.nil?
        outer_node = node.find_ancestor {|n| (n != node && n.kind_of?(ClassDefinition)) || n.kind_of?(Script)}
        if outer_node.kind_of?(ClassDefinition)
          outer_name = outer_node.name.identifier
        else
          outer_name = Mirah::JVM::Compiler::JVMBytecode.classname_from_filename(node.position.source.name || 'DashE')
        end
        id = (@anonymous_classes[outer_node] += 1)
        node.name_set(SimpleString.new("#{outer_name}$#{id}"))
      end
      name = node.name.identifier
      full_name = name
      package = scope.package
      if !name.include?('.') && package && !package.empty?
        full_name = "#{package}.#{name}"
      end
      if @known_types.include? full_name
        existing = @known_types[full_name]
        unless existing.node
          existing.node = node
          existing.scope = scope
        end
        existing
      else
        if InterfaceDeclaration === node
          klass = InterfaceDefinition
        else
          klass = TypeDefinition
        end
        scope.import(full_name, name)
        @known_types[full_name] = klass.new(self, scope, full_name, node)
      end
    end

    def get_mirror(name)
      @mirrors[name] ||= begin
        classname = name.tr('.', '/')
        stream = JRuby.runtime.jruby_class_loader.getResourceAsStream(classname + ".class")
        if stream
          BiteScript::ASM::ClassMirror.load(stream)
        else
          url = JRuby.runtime.jruby_class_loader.getResource(classname + ".java")
          if url
            file = java.io.File.new(url.toURI)
            mirrors = JavaSourceMirror.load(file, self)
            mirrors.each do |mirror|
              @mirrors[mirror.type.class_name] = mirror
            end if mirrors
            @mirrors[name]
          end
        end
      end
    end
    
    def getAbstractMethods(type)
      methods = []
      unless type.isError
        object = get_type("java.lang.Object")
        # TODO support abstract methods
        interfaces = [type]
        until interfaces.empty?
          interface = interfaces.pop
          abstract_methods = interface.declared_instance_methods.select {|m| m.abstract?}
          methods += abstract_methods.select do |m|
            begin
              # Skip methods defined on Object
              object.java_method(m.name, *m.argument_types)
              false
            rescue NameError
              true
            end
          end
          interfaces.concat(interface.interfaces)
        end
      end
      methods.map do |method|
        MethodType.new(method.name, method.argument_types, method.return_type, false)
      end
    end
  end
end
require 'mirah/jvm/types/basic_types'