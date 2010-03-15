require 'duby/typer'
require 'duby/jvm/types'
require 'duby/jvm/types/factory'

module Duby
  module Typer
    class JVM < Simple
      include Duby::JVM::Types
      
      attr_reader :transformer

      JavaLangTypes = %w[
        Appendable
        CharSequence
        Cloneable
        Comparable
        Iterable
        Readable
        Runnable

        Boolean
        Byte
        Character
        Class
        ClassLoader
        Compiler
        Double
        Enum
        Float
        InheritableThreadLocal
        Integer
        Long
        Math
        Number
        Object
        Package
        Process
        ProcessBuilder
        Runtime
        RuntimePermission
        SecurityManager
        Short
        StackTraceElement
        StrictMath
        String
        StringBuffer
        StringBuilder
        System
        Thread
        ThreadGroup
        ThreadLocal
        Throwable
        Void

        ArithmeticException
        ArrayIndexOutOfBoundsException
        ArrayStoreException
        ClassCastException
        ClassNotFoundException
        CloneNotSupportedException
        EnumConstantNotPresentException
        Exception
        IllegalAccessException
        IllegalArgumentException
        IllegalMonitorStateException
        IllegalStateException
        IllegalThreadStateException
        IndexOutOfBoundsException
        InstantiationException
        InterruptedException
        NegativeArraySizeException
        NoSuchFieldException
        NoSuchMethodException
        NullPointerException
        NumberFormatException
        RuntimeException
        SecurityException
        StringIndexOutOfBoundsException
        TypeNotPresentException
        UnsupportedOperationException

        AbstractMethodError
        AssertionError
        ClassCircularityError
        ClassFormatError
        Error
        ExceptionInInitializerError
        IllegalAccessError
        IncompatibleClassChangeError
        InstantiationError
        InternalError
        LinkageError
        NoClassDefFoundError
        NoSuchFieldError
        NoSuchMethodError
        OutOfMemoryError
        StackOverflowError
        ThreadDeath
        UnknownError
        UnsatisfiedLinkError
        UnsupportedClassVersionError
        VerifyError
        VirtualMachineError

        Deprecated
        Override
        SuppressWarnings
      ]

      def initialize(filename, transformer)
        @factory = AST.type_factory
        @transformer = transformer
        unless @factory.kind_of? TypeFactory
          raise "TypeFactory not installed"
        end
        @known_types = @factory.known_types
        classname = Duby::Compiler::JVM.classname_from_filename(filename)
        main_class = @factory.declare_type(classname)
        @known_types['self'] = main_class.meta

        # prepare java.lang types
        for type_name in JavaLangTypes
          @known_types[type_name] = type_reference("java.lang.#{type_name}")
        end

        @errors = []
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
        @known_types[name]
      end

      def null_type
        Null
      end
      
      def no_type
        Void
      end

      def array_type
        # TODO: allow other types for pre-1.2 profiles
        type_reference("java.util.List")
      end

      def hash_type
        # TODO: allow other types for pre-1.2 profiles
        type_reference("java.util.Map")
      end

      def known_type(name)
        @factory.known_type(name)
      end

      def learn_method_type(target_type, name, parameter_types, type, exceptions)
        static = target_type.meta?
        unless target_type.unmeta.kind_of?(TypeDefinition)
          raise "Method defined on #{target_type}"
        end
        if static
          target_type.unmeta.declare_static_method(name, parameter_types, type, exceptions)
        else
          target_type.declare_method(name, parameter_types, type, exceptions)
        end
        super
      end
      
      def infer_signature(method_def)
        signature = method_def.signature
        sig_args = signature.dup
        return_type = sig_args.delete(:return)
        exceptions = sig_args.delete(:throws)
        args = method_def.arguments.args || []
        static = method_def.kind_of? Duby::AST::StaticMethodDefinition
        if sig_args.size != args.size
          # If the superclass declares one method with the same name and
          # same number of arguments, assume we're overriding it.
          found = nil
          ambiguous = false
          classes = [self_type.superclass] + self_type.interfaces
          while classes.size > 0
            cls = classes.pop
            if static
              methods = cls.declared_class_methods
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
            signature[:throws] = found.exceptions
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
            signature[:throws] = method.exceptions
          end
        end
      end
    end
  end
end