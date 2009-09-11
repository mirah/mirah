require 'duby/typer'
require 'duby/jvm/types'

module Duby
  module JVM
    class TypeFactory
      include Types
      
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
    end
  end
  
  module Typer
    class JVM < Simple
      include Duby::JVM::Types

      def initialize(compiler)
        @factory = AST.type_factory
        unless @factory.kind_of? Duby::JVM::TypeFactory
          raise "TypeFactory not installed"
        end
        @known_types = @factory.known_types
        main_class = type_definition(
            compiler.class, type_reference(compiler.class.superclass))
        @known_types['self'] = main_class
      end
      
      def type_reference(name, array=false, meta=false)
        @factory.type(name, array, meta)
      end
      
      
      def alias_types(short, long)
        @known_types[short] = type_reference(long)
      end
      
      def name
        "JVM"
      end
      
      def type_definition(name, superclass)
        TypeDefinition.new(name, superclass)
      end

      def null_type
        Null
      end
      
      def no_type
        Void
      end
    end
  end
end