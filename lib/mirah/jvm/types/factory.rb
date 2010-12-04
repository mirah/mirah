require 'jruby'
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
      begin
        return get_type(name)
      rescue NameError => ex
        raise ex if scope.nil?
      end

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

    def package_search(name, scope)
      packages = []
      packages << scope.static_scope.package unless scope.static_scope.package.empty?
      packages.concat(scope.static_scope.search_packages)
      packages << 'java.lang'
      packages.each do |package|
        begin
          return get_type("#{package}.#{name}")
        rescue
        end
      end
      raise NameError, "Cannot find class #{name}"
    end

    def get_type(full_name)
      type = @known_types[full_name]
      return type.basic_type if type
      type = Type.new(get_mirror(full_name)).load_extensions
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
        classname = name.tr('.', '/') + ".class"
        stream = JRuby.runtime.jruby_class_loader.getResourceAsStream(classname)
        raise NameError, "Class '#{name}' not found." unless stream
        BiteScript::ASM::ClassMirror.load(stream)
      end
    end
  end
end