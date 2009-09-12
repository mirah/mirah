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
        if target_type.respond_to? :get_method
          method = target_type.get_method(name, parameter_types)
          raise NoMethodError, "Method #{name}(#{parameter_types.join ', '}) on #{target_type} not found" unless method
          result = method.return_type
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