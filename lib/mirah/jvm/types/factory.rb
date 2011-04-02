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
  class TypeFactory
    BASIC_TYPES = {
      "boolean" => Boolean,
      "byte" => Byte,
      "char" => Char,
      "short" => Short,
      "int" => Int,
      "long" => Long,
      "float" => Float,
      "double" => Double,
      "fixnum" => Int,
      "string" => String,
      "java.lang.String" => String,
      "String" => String,
      "java.lang.Object" => Object,
      "Object" => Object,
      "java.lang.Class" => ClassType,
      "java.lang.Iterable" => Iterable,
      "Iterable" => Iterable,
      "void" => Void,
      "notype" => Void,
      "null" => Null,
      "dynamic" => DynamicType.new
    }.freeze

    attr_accessor :package
    attr_reader :known_types

    class ParanoidHash < Hash
      def []=(k, v)
        raise ArgumentError, "Can't store nil for key #{k.inspect}" if v.nil?
        super(k, v)
      end
    end

    def initialize
      @known_types = ParanoidHash.new
      @known_types.update(BASIC_TYPES)
      @declarations = []
      @mirrors = {}
    end

    def initialize_copy(other)
      @known_types = other.known_types.dup
      @known_types.delete_if do |key, value|
        value.basic_type.kind_of?(Mirah::JVM::Types::TypeDefinition)
      end
      @declarations = []
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
      type = type.array_type if array
      type = type.meta if meta
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
      saved_ex = nil
      begin
        return get_type(name)
      rescue NameError => ex
        saved_ex = ex
      end

      if scope
        imports = scope.static_scope.imports
        if imports.include?(name)
          name = imports[name] while imports.include?(name)
          return get_type(name)
        end

        # TODO support inner class names
        if name !~ /\./
          return package_search(name, scope)
        end
      end
      raise saved_ex
    end

    def package_search(name, scope)
      packages = []
      packages << scope.static_scope.package unless scope.static_scope.package.empty?
      packages.concat(scope.static_scope.search_packages)
      packages << 'java.lang'
      packages.each do |package|
        begin
          return get_type("#{package}.#{name}")
        rescue NameError
        end
      end
      raise NameError, "Cannot find class #{name}"
    end

    def get_type(full_name)
      type = @known_types[full_name]
      return type.basic_type if type
      begin
        mirror = get_mirror(full_name)
      rescue NameError => ex
        if full_name =~ /^(.+)\.([^.]+)/
          outer_name = $1
          inner_name = $2
          begin
            outer_type = get_type(outer_name)
            full_name = "#{outer_type.name}$#{inner_name}"
          rescue NameError
            raise ex
          end
          mirror = get_mirror(full_name)
        else
          raise ex
        end
      end
      type = Type.new(mirror).load_extensions
      if full_name.include? '$'
        @known_types[full_name.gsub('$', '.')] = type
      end
      @known_types[full_name] = type
    end

    def known_type(scope, name)
      basic_type(scope, name) rescue nil
    end

    def declare_type(scope, name)
      full_name = name
      package = scope.static_scope.package
      if !name.include?('.') && !package.empty?
        full_name = "#{package}.#{name}"
      end
      if @known_types.include? full_name
        @known_types[full_name]
      else
        scope.static_scope.import(full_name, name)
        @known_types[full_name] = TypeDefinition.new(full_name, nil)
      end
    end

    def define_type(node)
      name = node.name
      full_name = name
      package = node.static_scope.package
      if !name.include?('.') && !package.empty?
        full_name = "#{package}.#{name}"
      end
      if @known_types.include? full_name
        existing = @known_types[full_name]
        existing.node ||= node
        existing
      else
        if Mirah::AST::InterfaceDeclaration === node
          klass = InterfaceDefinition
        else
          klass = TypeDefinition
        end
        node.scope.static_scope.import(full_name, name)
        @known_types[full_name] = klass.new(full_name, node)
      end
    end

    def no_type
      Void
    end

    def get_mirror(name)
      @mirrors[name] ||= begin
        classname = name.tr('.', '/')
        stream = JRuby.runtime.jruby_class_loader.getResourceAsStream(classname + ".class")
        if stream
          BiteScript::ASM::ClassMirror.load(stream) if stream
        else
          url = JRuby.runtime.jruby_class_loader.getResource(classname + ".java")
          if url
            file = java.io.File.new(url.toURI)
            mirrors = JavaSourceMirror.load(file, self)
            mirrors.each do |mirror|
              @mirrors[mirror.type.class_name] = mirror
            end if mirrors
            @mirrors[name]
          else
            raise NameError, "Class '#{name}' not found."
          end
        end
      end
    end
  end
end