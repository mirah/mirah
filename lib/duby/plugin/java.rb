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
      
      def method_type(typer, target_type, name, parameter_types)
        return if target_type.nil? or parameter_types.any? {|t| t.nil?}
        if target_type.respond_to? :get_method
          method = target_type.get_method(name, parameter_types)
          unless method || target_type.basic_type.kind_of?(TypeDefinition)
            raise NoMethodError, "Method %s(%s) on %s not found" %
                [name, parameter_types.join(', '), target_type]
          end
          result = method.return_type if method
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

  typer_plugins << Typer::JavaTyper.new
end