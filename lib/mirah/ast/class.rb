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
  class ClassDefinition
    attr_accessor :current_access_level
    attr_accessor :abstract

    def append_node(node)
      if unless body.kind_of?(Body)
        new_body = Body.new(position)
        old_body = body
        self.body = new_body
        new_body << old_body
      end
      body << node
      node
    end

    def <<(node)
      append_node(node)
      self
    end

    def infer(typer, expression)
      resolve_if(typer) do
        static_scope = typer.add_scope(self)
        annotations.each {|a| a.infer(typer, true)} if annotations
        interfaces.each {|i| typer.infer(i.typeref, true)} if interfaces
        superclass = typer.infer(self.superclass.typeref) is self.superclass
        interfaces = self.interfaces.map {|i| typer.typeref(i.typeref, true)} if self.interfaces
        typer.define_type(self, name.identifier, superclass, interfaces) do |self_type|
          static_scope.self_type = self_type
          typer.infer(body, false) if body
        end
      end
    end

    def implements(*types)
      raise ArgumentError if types.any? {|x| x.nil?}
      types.each do |type|
        interfaces.add(type)
      end
    end

    def top_level?
      true
    end
  end

  class InterfaceDeclaration

  end

  class ClosureDefinition

  end

 class FieldDeclaration
    def infer(typer, expression)
      resolve_if(typer) do
        annotations.each {|a| a.infer(typer, true)} if annotations
        typer.infer(type, true)
      end
    end

    def resolved!(typer)
      klass = findParent(ClassDefinition.class)
      if static
        typer.learn_static_field_type(klass, name.identifier, @inferred_type)
      else
        typer.learn_field_type(klass, name.identifier, @inferred_type)
      end
      super
    end
  end

  class FieldAssignment
    def infer(typer, expression)
      resolve_if(typer) do
        klass = findParent(ClassDefinition.class)
        annotations.each {|a| a.infer(typer, true)} if annotations
        if static
          typer.learn_static_field_type(klass, name.identifier, typer.infer(value, true))
        else
          typer.learn_field_type(klass, name.identifier, typer.infer(value, true))
        end
      end
    end
  end

  class FieldAccess
    def infer(typer, expression)
      resolve_if(typer) do
        klass = findParent(ClassDefinition.class)
        if static
          typer.static_field_type(klass, name.identifier)
        else
          typer.field_type(klass, name.identifier)
        end
      end
    end
  end

  # class AccessLevel < Node
  #   include ClassScoped
  #   include Named
  # 
  #   def initialize(parent, line_number, name)
  #     super(parent, line_number)
  #     self.name = name
  #     class_scope.current_access_level = name.to_sym
  #   end
  # 
  #   def infer(typer, expression)
  #     typer.no_type
  #   end
  # end
  # 
  # class Include < Node
  #   def infer(typer, expression)
  #     children.each do |type|
  #       typeref = type.type_reference(typer)
  #       the_scope = typer.get_scope(self)
  #       the_scope.self_type = the_scope.self_type.include(typeref)
  #     end
  #   end
  # end
  # 
  # defmacro("include") do |transformer, fcall, parent|
  #   raise "Included Class name required" unless fcall.parameters.size > 0
  #   Include.new(parent, fcall.position) do |include_node|
  #     fcall.parameters.map do |constant|
  #       constant.parent = include_node
  #       constant
  #     end
  #   end
  # end

  class Constant
    def infer(typer, expression)
      @inferred_type ||= begin
        # TODO lookup constant, inline if we're supposed to.
        typer.infer(typeref, true)
      end
    end
  end
end
