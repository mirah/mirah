require 'duby/typer'
require 'duby/jvm/method_lookup'
require 'duby/jvm/types'
require 'java'

module Duby
  module Typer
    class JavaTyper < BaseTyper
      include Duby::JVM::MethodLookup
      include Duby::JVM::Types
      
      def initialize
      end
      
      def name
        "Java"
      end

      def java_to_duby(java_class)
        return Void unless java_class
        
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
          when Long
            return nil if parameter_types.length != 1
            return nil if parameter_types[0] != Long
            return Long
          else
            log "Unknown method \"#{name}\" on type long"
            return nil
          end
        when '+'
          case target_type
          when String
            return String
          end
        else
          if name == 'length'
            if target_type.array?
              return Int
            end
          elsif name == '[]'
            if target_type.array?
              return target_type.component_type
            end
          elsif name == '[]='
            # needs more checks for numbe of args, etc
            if target_type.array? && parameter_types.size == 2
              return parameter_types[1]
            end
          end
          begin
            java_type = target_type.jvm_type
            arg_types = parameter_types.map {|type| type.jvm_type}
          rescue NameError
            Typer.log "Failed to infer Java types for method \"#{name}\" #{parameter_types} on #{target_type}"
            return nil
          end
          
          method = find_method(java_type, name, arg_types, target_type.meta?)
          
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