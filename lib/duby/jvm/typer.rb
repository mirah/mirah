require 'duby/typer'
require 'duby/jvm/types'
require 'duby/jvm/types/factory'

module Duby
  module Typer
    class JVM < Simple
      include Duby::JVM::Types

      def initialize(compiler)
        @factory = AST.type_factory
        unless @factory.kind_of? TypeFactory
          raise "TypeFactory not installed"
        end
        @known_types = @factory.known_types
        main_class = type_definition(
            compiler.class, type_reference(compiler.class.superclass))
        @known_types['self'] = main_class.meta
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
        typedef = TypeDefinition.new(name, superclass)
        @known_types[typedef.name] = typedef
      end

      def null_type
        Null
      end
      
      def no_type
        Void
      end
      
      def learn_method_type(target_type, name, parameter_types, type)
        static = target_type.meta?
        target_type = target_type.unmeta if static
        unless target_type.kind_of?(TypeDefinition)
          raise "Method defined on #{target_type}"
        end
        if static
          target_type.declare_static_method(name, parameter_types, type)
        else
          target_type.declare_method(name, parameter_types, type)
        end
        super
      end
    end
  end
end