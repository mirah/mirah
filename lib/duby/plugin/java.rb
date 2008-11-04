require 'duby/typer'
require 'duby/jvm/method_lookup'
require 'java'

module Duby
  module Typer
    class JavaTyper < BaseTyper
      include Duby::JVM::MethodLookup
      
      def initialize
        type_mapper[AST::type(:string)] = AST::type("java.lang.String")
        type_mapper[AST::type(:fixnum)] = AST::type("int")
      end
      
      def name
        "Java"
      end

      def type_mapper
        @type_mapper ||= {}
      end

      def mapped_type(type)
        type_mapper[type] || type
      end
      
      def java_to_duby(java_class)
        return AST::TypeReference::NoType unless java_class
        
        if java_class.array?
          AST::type(java_class.component_type.name, true)
        else
          AST::type(java_class.name)
        end
      end
      
      def method_type(typer, target_type, name, parameter_types)
        case name
        when '-'
          case target_type
          when AST.type(:long)
            return nil if parameter_types.length != 1
            return nil if parameter_types[0] != AST.type(:long)
            return AST.type(:long)
          else
            log "Unknown method \"#{name}\" on type long"
          end
        when '+'
          case target_type
          when AST.type(:string)
            return AST.type(:string)
          end
        else
          mapped_target = mapped_type(target_type)
          mapped_parameters = parameter_types.map {|type| mapped_type(type)}
          begin
            java_type = Java::JavaClass.for_name(mapped_target.name)
            arg_types = mapped_parameters.map {|type| Java::JavaClass.for_name(type.name)}
          rescue NameError
            Typer.log "Failed to infer Java types for method \"#{name}\" #{mapped_parameters} on #{mapped_target}"
            return nil
          end
          
          method = find_method(java_type, name, arg_types, mapped_target.meta?)
          
          if method
            if Java::JavaConstructor === method
              result = java_to_duby(method.declaring_class)
            else
              result = java_to_duby(method.return_type)
            end
          end

          if result
            log "Method type for \"#{name}\" #{parameter_types} on #{target_type} = #{result}"
          else
            log "Method type for \"#{name}\" #{parameter_types} on #{target_type} not found"
          end

          result
        end
      end
    end
  end

  typer_plugins << Typer::JavaTyper.new
end