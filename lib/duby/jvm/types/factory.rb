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
    end

    def define_types(builder)
      @declarations.each do |declaration|
        declaration.define(builder)
      end
    end

    def type(name, array=false, meta=false)
      type = basic_type(name)
      type = type.meta if meta
      type = type.array_type if array
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
      return @known_types[name].basic_type if @known_types[name]
      raise ArgumentError, "Bad Type #{orig}" if name =~ /Java::/
      raise ArgumentError, "Bad Type #{orig.inspect}" if name == '' || name.nil?
      full_name = name
      begin
        @known_types[name] = Type.new(Java::JavaClass.for_name(full_name))
      rescue NameError
        unless full_name.include? '.'
          full_name = "java.lang.#{full_name}"
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

      if @known_types.include? name
        existing = @known_types[name]
        existing.node ||= node
        existing
      else
        full_name = name
        if !name.include?('.') && package
          full_name = "#{package}.#{name}"
        end
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
      @known_types[from] = type(to)
    end

    def no_type
      Void
    end
    
    def fixnum(parent, line_number, literal)
      FixnumLiteralNode.new(parent, line_number, literal)
    end
    
    def float(parent, line_number, literal)
      FloatLiteralNode.new(parent, line_number, literal)
    end
  end

  class FixnumLiteralNode < AST::Fixnum
    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type = FixnumLiteral.new(@literal)
    end

    def compile(compiler, expression)
      if expression
        inferred_type.literal(compiler.method, @literal)
      end
    end
  end

  class FloatLiteralNode < AST::Float
    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type = FloatLiteral.new(@literal)
    end

    def compile(compiler, expression)
      if expression
        inferred_type.literal(compiler.method, @literal)
      end
    end
  end
end