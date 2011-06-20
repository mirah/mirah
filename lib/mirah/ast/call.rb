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

module Mirah::AST
  class FunctionalCall
    def infer(typer, expression)
      unless @inferred_type
        @self_type ||= typer.get_scope(self).self_type
        receiver_type = @self_type
        should_defer = false

        parameter_types = parameters.map do |param|
          typer.infer(param, true) || should_defer = true
        end

        parameter_types << Mirah::AST.block_type if block

        scope = typer.get_scope(self)
        unless should_defer
          if parameters.size == 1 && typer.known_type(scope, typeref.name)
            # cast operation
            resolved!
            @inferred_type = typer.known_type(scope, typeref.name)
            cast = Cast.new(position, typeref, parameters.remove(0))
            return inline(typer, cast)
          elsif parameters.size == 0 && typer.get_scope(self).include?(name.identifier)
            local = LocalAccess.new(position, name)
            local.scope = @scope
            return inline(typer, local)
          else
            @inferred_type = typer.method_type(receiver_type, name.identifier,
                                               parameter_types)
            if @inferred_type.kind_of? InlineCode
              return inline(typer, @inferred_type.inline(typer.transformer, self))
            end
          end
        end

        if @inferred_type
          if block
            method = receiver_type.get_method(name.identifier, parameter_types)
            block.prepare(typer, method)
          end
          @inferred_type = receiver_type if @inferred_type.void?
          resolved!
        else
          if should_defer || receiver_type.nil?
            message = nil
          else
            parameter_names = parameter_types.map {|t| t.full_name}.join(', ')
            receiver = receiver_type.full_name
            desc = "#{name.identifier}(#{parameter_names})"
            kind = receiver_type.meta? ? "static" : "instance"
            message = "Cannot find #{kind} method #{desc} on #{receiver}"
          end
          typer.defer(self, message)
        end
      end

      @inferred_type
    end
  end

  class Call
    def infer(typer, expression)
      unless @inferred_type
        receiver_type = typer.infer(target, true)
        should_defer = receiver_type.nil?
        parameter_types = parameters.map do |param|
          typer.infer(param, true) || should_defer = true
        end

        parameter_types << Mirah::AST.block_type if block

        scope = typer.get_scope(self)
        unless should_defer
          typeref = self.typeref(true)
          if parameters.size == 1 && typer.known_type(scope, typeref.name)
            # Support casts to fully-qualified names and inner classes.
            begin
              type = inferred_type = typer.type_reference(scope, typeref.name, typeref.array)
              @inferred_type = type unless (type && type.error?)
              if @inferred_type
                resolved!
                cast = Cast.new(position, typeref, parameters.remove(0))
                return inline(typer, cast)
              end
            rescue
            end
          end
          @inferred_type = typer.method_type(receiver_type, name.identifier,
                                             parameter_types)
          if @inferred_type.kind_of? InlineCode
            return inline(typer, @inferred_type)
          end
        end

        if @inferred_type
          if block && !receiver_type.error?
            method = receiver_type.get_method(name.identifier, parameter_types)
            block.prepare(typer, method)
          end
          @inferred_type = receiver_type if @inferred_type.void?
          resolved!
        else
          if should_defer
            message = nil
          else
            parameter_names = parameter_types.map {|t| t.full_name}.join(', ')
            receiver = receiver_type.full_name
            desc = "#{name.identifier}(#{parameter_names})"
            kind = receiver_type.meta? ? "static" : "instance"
            message = "Cannot find #{kind} method #{desc} on #{receiver}"
          end
          typer.defer(self, message)
        end
      end

      @inferred_type
    end
  end


  class Colon2
    def infer(typer, expression)
      resolve_if(typer) do
        typer.type_reference(scope, typeref.name, false, true)
      end
    end
  end

  class Super
    def call_parent
      find_parent(MethodDefinition.class)
    end

    def name
      call_parent.name
    end

    def infer(typer, expression)
      @self_type ||= typer.get_scope(self).self_type.superclass

      unless @inferred_type
        receiver_type = call_parent.defining_class.superclass
        should_defer = receiver_type.nil?
        parameter_types = parameters.map do |param|
          typer.infer(param, true) || should_defer = true
        end

        unless should_defer
          @inferred_type = typer.method_type(receiver_type, name,
                                             parameter_types)
        end

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end

  class ZSuper
    def call_parent
      find_parent(MethodDefinition.class)
    end

    def name
      call_parent.name
    end

    def parameters
      @parameters ||= call_parent.parameters
    end

    def infer(typer, expression)
      @self_type ||= typer.get_scope(self).self_type.superclass

      unless @inferred_type
        receiver_type = call_parent.defining_class.superclass
        should_defer = receiver_type.nil?
        parameter_types = parameters.map do |param|
          typer.infer(param, true) || should_defer = true
        end

        unless should_defer
          @inferred_type = typer.method_type(receiver_type, name,
                                             parameter_types)
        end

        @inferred_type ? resolved! : typer.defer(self)
      end

      @inferred_type
    end
  end
end