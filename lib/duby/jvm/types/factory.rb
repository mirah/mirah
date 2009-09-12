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
      "java.lang.Object" => Object,
      "void" => Void,
      "notype" => Void,
      "null" => Null
    }.freeze

    attr_reader :known_types

    def initialize
      @known_types = BASIC_TYPES.dup
    end

    def type(name, array=false, meta=false)
      type = basic_type(name)
      type = type.meta if meta
      type = type.array_type if array
      return type
    end
    
    def basic_type(name)
      return name.basic_type if name.kind_of? Type
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
      @known_types[name] = Type.new(Java::JavaClass.for_name(name))
    end

    def alias(from, to)
      @known_types[from] = type(to)
    end

    def no_type
      Void
    end
    
    def fixnum(parent, literal)
      FixnumLiteralNode.new(parent, literal)
    end
    
    def float(parent, literal)
      FloatLiteralNode.new(parent, literal)
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