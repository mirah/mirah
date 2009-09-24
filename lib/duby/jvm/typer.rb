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
            compiler.class, type_reference(compiler.class.superclass),
            compiler.class.interfaces)
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
      
      def type_definition(name, superclass, interfaces)
        typedef = TypeDefinition.new(name, superclass, interfaces)
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
      
      def infer_signature(method_def)
        signature = method_def.signature
        args = method_def.arguments.args || []
        static = method_def.kind_of? Duby::AST::StaticMethodDefinition
        if signature.size != args.size + 1
          # If the superclass declares one method with the same name and
          # same number of arguments, assume we're overriding it.
          found = nil
          ambiguous = false
          classes = [self_type.superclass] + self_type.interfaces
          while classes.size > 0
            cls = classes.pop
            if static
              methods = cls.declared_static_methods
            else
              methods = cls.declared_instance_methods
            end
            methods.each do |method|
              if method.name == method_def.name &&
                 method.argument_types.size == args.size
                if found && found.argument_types != method.argument_types
                  ambiguous = true
                else
                  found ||= method
                end
              end
            end
            classes << cls.superclass if cls.superclass
          end
          if found && !ambiguous
            signature[:return] = found.actual_return_type
            args.zip(found.argument_types) do |arg, type|
              signature[arg.name.intern] = type
            end
          end
        elsif signature[:return].nil? && !static
          arg_types = args.map do |arg|
            signature[arg.name.intern]
          end
          method = self_type.find_method(
              self_type, method_def.name, arg_types, false)
          interfaces = self_type.interfaces.dup
          until method || interfaces.empty?
            interface = interfaces.pop
            method = interface.find_method(
                interface, method_def.name, arg_types, false)
          end
          if method
            signature[:return] = method.actual_return_type
          end
        end
      end
    end
  end
end