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

require 'mirah/typer'
require 'mirah/jvm/types'
require 'mirah/jvm/types/factory'

module Mirah
  module JVM
    class Typer < Mirah::Typer::Simple
      include Mirah::JVM::Types

      attr_reader :transformer

      def initialize(transformer)
        @factory = AST.type_factory
        @transformer = transformer
        unless @factory.kind_of? TypeFactory
          raise "TypeFactory not installed"
        end
        @known_types = @factory.known_types
        @known_types['dynamic'] = DynamicType.new
        @errors = []
      end

      def set_filename(scope, filename)
        classname = Mirah::JVM::Compiler::JVMBytecode.classname_from_filename(filename)
        main_class = @factory.declare_type(scope, classname)
        @known_types['self'] = main_class.meta
      end

      def type_reference(scope, name, array=false, meta=false)
        begin
          @factory.type(scope, name, array, meta)
        rescue NameError => ex
          known_types[name] = Mirah::AST.error_type
          raise Mirah::InferenceError.wrap(ex, nil)
        end
      end

      def name
        "JVM"
      end

      def type_definition(scope, name, superclass, interfaces)
        imports = scope.static_scope.imports
        name = imports[name] while imports.include?(name)
        package = scope.static_scope.package
        unless name =~ /\./ || package.empty?
          name = "#{package}.#{name}"
        end

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
        type_reference(nil, "java.util.List")
      end

      def hash_type
        # TODO: allow other types for pre-1.2 profiles
        type_reference(nil, "java.util.Map")
      end

      def regexp_type
        type_reference(nil, "java.util.regex.Pattern")
      end

      def known_type(scope, name)
        @factory.known_type(scope, name)
      end

      def fixnum_type(value)
        FixnumLiteral.new(value)
      end

      def float_type(value)
        FloatLiteral.new(value)
      end

      def learn_method_type(target_type, name, parameter_types, type, exceptions)
        static = target_type.meta?
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
        static = method_def.kind_of? Mirah::AST::StaticMethodDefinition
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
            signature[:return] = found.return_type
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
            signature[:return] = method.return_type
            signature[:throws] = method.exceptions
          end
        end
      end
    end
  end
end