require 'mirah/typer'
require 'mirah/jvm/method_lookup'
require 'mirah/jvm/types'
require 'java'

module Mirah
  module Typer
    class JavaTyper < BaseTyper
      include Mirah::JVM::MethodLookup
      include Mirah::JVM::Types
      
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
            raise NoMethodError, "Cannot find %s method %s(%s) on %s" %
                [ target_type.meta? ? "static" : "instance",
                  name,
                  parameter_types.map{|t| t.full_name}.join(', '),
                  target_type.full_name
                ]
          end
          if method
            result = method.return_type
          elsif typer.last_chance && target_type.meta? &&
              name == 'new' && parameter_types == []
            unmeta = target_type.unmeta
            if unmeta.respond_to?(:default_constructor)
              result = unmeta.default_constructor
              typer.last_chance = false if result
            end
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

  typer_plugins << Typer::JavaTyper.new
end