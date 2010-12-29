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