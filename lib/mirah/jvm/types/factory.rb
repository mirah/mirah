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
    java_import 'org.mirah.typer.BaseTypeFuture'
    java_import 'org.mirah.typer.BlockType'
    java_import 'org.mirah.typer.ErrorType'
    java_import 'org.mirah.typer.TypeFuture'
    java_import 'org.mirah.typer.TypeSystem'
    java_import 'mirah.lang.ast.InterfaceDeclaration'
    include TypeSystem

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

    def wrap(resolved_type)
      future = BaseTypeFuture.new(nil)
      future.resolved(resolved_type) if resolved_type
      future
    end

    def cache_and_wrap(resolved_type)
      @futures[resolved_type.name] ||= wrap(resolved_type)
    end
    def cache_and_wrap_type(name)
      @futures[name] ||= wrap(type(nil, name))
    end

    # TypeSystem methods
    def getNullType; cache_and_wrap_type('null') end
    def getVoidType; cache_and_wrap_type('void') end
    def getBaseExceptionType; cache_and_wrap_type('java.lang.Throwable') end
    def getDefaultExceptionType; cache_and_wrap_type('java.lang.Exception') end
    def getHashType; cache_and_wrap_type('java.util.HashMap') end
    def getRegexType; cache_and_wrap_type('java.util.regex.Pattern') end
    def getStringType; cache_and_wrap_type('java.lang.String') end
    def getBooleanType; cache_and_wrap_type('boolean') end
    # TODO narrowing
    def getFixnumType(value); cache_and_wrap_type('int') end
    def getCharType(value) cache_and_wrap_type('char') end
    def getFloatType(value); cache_and_wrap_type('float') end
    def getMetaType(type)
      if type.kind_of?(Type)
        type.meta
      else
        future = BaseTypeFuture.new(nil)
        type.on_update {|_, resolved| future.resolved(resolved.meta)}
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
    def get(typeref)
      basic_type = @futures[typeref.name] || cache_and_wrap_type(typeref.name)
      if typeref.isArray
        getArrayType(basic_type)
      elsif typeref.isStatic
        getMetaType(basic_type)
      else
        basic_type
      end
    end
    def getLocalType(scope, name)
      scope.local_type(name)
    end

    def getMethodType(target, name, argTypes, position=nil)
      if target.respond_to?(:isError) && target.isError
        return target
      end
      type = BaseTypeFuture.new(nil)
      target.find_method(target, name, argTypes, target.meta?) do |method|
        if method.nil?
          type.resolved(ErrorType.new([
              ["Cannot find %s method %s(%s) on %s" %
                  [ target.meta? ? "static" : "instance",
                    name,
                    argTypes.map{|t| t.full_name}.join(', '),
                    target.full_name]]]))
        elsif method.kind_of?(Exception)
          type.resolved(ErrorType.new([method.message]))
        else
          result = method.return_type
          if result.kind_of?(TypeFuture)
            if result.isResolved
              type.resolved(result.resolve)
            else
              result.onUpdate {|x, resolved| type.resolved(resolved) }
            end
          else
            cached = cache_and_wrap_type(result.name).resolve
            type.resolved(cached)
          end
        end
      end
      result = super(target, name, argTypes, position)
      result.assign(type, position)
      result
    end
    def getMethodDefType(target, name, argTypes)
      args = argTypes.map {|a| a.resolve}
      target = target.resolve
      type = getMethodType(target, name, args)
      type.onUpdate do |m, resolved|
        if Mirah::Typer.verbose
          Mirah::Typer.log "Learned %s method %s.%s%s = %s" % 
              [target.meta? ? "static" : "instance",
                target,
                name,
                argTypes,
                resolved.full_name]
        end
        if target.meta?
          target.unmeta.declare_static_method(name, argTypes, resolved, [])
        else
          target.declare_method(name, argTypes, resolved, [])
        end
      end
      if type.kind_of?(ErrorType)
        puts "Got error type for method #{name} on #{target.resolve} (#{target.resolve.class})"
      end
      type
    end
    def getMainType(scope, script)
      filename = File.basename(script.position.filename || 'DashE')
      classname = Mirah::JVM::Compiler::JVMBytecode.classname_from_filename(filename)
      getMetaType(cache_and_wrap(declare_type(scope, classname)))
    end
    def defineType(scope, node, name, superclass, interfaces)
      # TODO what if superclass or interfaces change later?
      type = define_type(scope, node)
      future = @futures[type.name]
      if future
        future.resolved(type)
      else
        cache_and_wrap(type)
      end
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

    def block_type
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
      if !name.include?('.') && package && !package.empty?
        full_name = "#{package}.#{name}"
      end
      if @known_types.include? full_name
        @known_types[full_name]
      else
        scope.import(full_name, name)
        @known_types[full_name] = TypeDefinition.new(self, full_name, nil)
      end
    end

    def define_type(scope, node)
      name = node.name.identifier
      full_name = name
      package = scope.package
      if !name.include?('.') && package && !package.empty?
        full_name = "#{package}.#{name}"
      end
      if @known_types.include? full_name
        existing = @known_types[full_name]
        existing.node ||= node
        existing
      else
        if InterfaceDeclaration === node
          klass = InterfaceDefinition
        else
          klass = TypeDefinition
        end
        scope.import(full_name, name)
        @known_types[full_name] = klass.new(self, full_name, node)
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
  end
end
require 'mirah/jvm/types/basic_types'