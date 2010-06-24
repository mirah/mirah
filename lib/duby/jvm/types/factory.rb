require 'jruby'
module Duby::JVM::Types
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

    def initialize(filename='')
      @known_types = ParanoidHash.new
      @known_types.update(BASIC_TYPES)
      @declarations = []
      @package = File.dirname(filename).tr('/', '.')
      @package.sub! /^\.+/, ''
      @package = nil if @package.empty?
      @search_packages = [@package, 'java.lang']
      @mirrors = {}
    end

    def initialize_copy(other)
      @known_types = other.known_types.dup
      @known_types.delete_if do |key, value|
        value.basic_type.kind_of?(Duby::JVM::Types::TypeDefinition)
      end
      @declarations = []
    end

    def define_types(builder)
      @declarations.each do |declaration|
        declaration.define(builder)
      end
    end

    def type(name, array=false, meta=false)
      if name.kind_of?(BiteScript::ASM::Type)
        if name.getDescriptor[0] == ?[
          return type(name.getElementType, true, meta)
        else
          name = name.getClassName
        end
      end
      type = basic_type(name)
      type = type.array_type if array
      type = type.meta if meta
      return type
    end

    def basic_type(name)
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
      if name.include? '.'
        alt_names = []
      else
        alt_names = @search_packages.map {|package| "#{package}.#{name}"}
      end
      full_name = name
      begin
        type = @known_types[full_name].basic_type if @known_types[full_name]
        type ||= begin
          Type.new(get_mirror(full_name)).load_extensions
        end
        @known_types[name] = @known_types[full_name] = type
      rescue NameError
        unless alt_names.empty?
          full_name = alt_names.shift
          retry
        end
        raise $!
      end
    end

    def known_type(name)
      basic_type(name) rescue nil
    end

    def declare_type(node)
      if node.kind_of? ::String
        name = node
        node = nil
      else
        name = node.name
      end

      full_name = name
      if !name.include?('.') && package
        full_name = "#{package}.#{name}"
      end
      if @known_types.include? full_name
        existing = @known_types[full_name]
        existing.node ||= node
        existing
      else
        if Duby::AST::InterfaceDeclaration === node
          klass = InterfaceDefinition
        else
          klass = TypeDefinition
        end
        @known_types[full_name] = klass.new(full_name, node)
        @known_types[name] = @known_types[full_name]
      end
    end

    def alias(from, to)
      if from == '*'
        @search_packages << to.sub(".*", "")
      else
        @known_types[from] = type(to)
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