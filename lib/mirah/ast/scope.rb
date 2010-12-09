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

module Mirah
  module AST
    module Scoped
      def scope
        @scope ||= begin
          scope = parent
          until scope.nil? || scope.class.include?(Scope)
            scope = scope.parent
          end
          scope
        end
      end

      def containing_scope
        scope = self.scope.static_scope
        while !scope.shadowed?(name) && scope.parent && scope.parent.include?(name)
          scope = scope.parent
        end
        scope
      end
    end

    module Scope
      include Scoped
      attr_writer :static_scope, :type_scope
      def static_scope
        @static_scope ||= StaticScope.new(self)
      end
    end

    module ClassScoped
      def class_scope
        @class_scope ||= begin
          scope = parent
          scope = scope.parent until scope.nil? || ClassDefinition === scope
          scope
        end
      end
    end

    class StaticScope
      java_import 'java.util.LinkedHashMap'
      attr_reader :parent
      attr_writer :self_type, :self_node, :package

      def initialize(node, parent=nil)
        @scope_node = node
        @vars = {}
        @var_types = {}
        @parent = parent
        @children = {}
        @imports = {}
        @search_packages = []
        @shadowed = {}
      end

      def <<(name)
        @vars[name] = true
      end

      def shadow(name)
        @shadowed[name] = @vars[name] = true
      end

      def shadowed?(name)
        @shadowed[name]
      end

      def locals
        @vars.keys
      end

      def local_type(name)
        @var_types[name]
      end

      def learn_local_type(name, type)
        return unless type
        existing_type = local_type(name)
        if existing_type
          unless existing_type.assignable_from?(type)
            raise Mirah::Typer::InferenceError.new(
                "Can't assign #{type.full_name} to " \
                "variable of type #{existing_type.full_name}")
          end
          existing_type
        elsif type
          @var_types[name] = type
        end
      end

      def include?(name, include_parent=true)
        @vars.include?(name) ||
            (include_parent && parent && parent.include?(name))
      end

      def captured?(name)
        if !include?(name, false)
          return false
        elsif parent && parent.include?(name)
          return true
        else
          return children.any? {|child| child.include?(name, false)}
        end
      end

      def children
        @children.keys
      end

      def add_child(scope)
        @children[scope] = true
      end

      def remove_child(scope)
        @children.delete(scope)
      end

      def parent=(parent)
        @parent.remove_child(self) if @parent
        parent.add_child(self)
        @parent = parent
      end

      def outer_scope
        node = @scope_node.scope
        node && node.static_scope
      end

      def self_type
        if @self_type.nil? && parent
          @self_type = parent.self_type
        end
        @self_type
      end

      def self_node
        if @self_node.nil? && parent
          @self_node = parent.self_node
        end
        @self_node
      end

      def binding_type(defining_class=nil, duby=nil)
        @binding_type ||= begin
          if parent
            parent.binding_type(defining_class, duby)
          else
            name = "#{defining_class.name}$#{duby.tmp}"
            factory = Mirah::AST.type_factory
            if factory
              factory.declare_type(@scope_node, name)
            else
              Mirah::AST::TypeReference.new(name, false, false)
            end
          end
        end
      end

      def binding_type=(type)
        if parent
          parent.binding_type = type
        else
          @binding_type = type
        end
      end

      def has_binding?
        @binding_type != nil || (parent && parent.has_binding?)
      end

      def package
        @package || outer_scope.package
      end

      def fetch_imports(map)
        parent_scope = outer_scope
        parent_scope.fetch_imports(map) if parent_scope

        map.update(@imports)
      end

      def fetch_packages(list)
        parent_scope = outer_scope
        parent_scope.fetch_packages(list) if parent_scope

        list.concat(@search_packages)
      end

      def imports
        @cached_imports ||= fetch_imports({})
      end

      def search_packages
        @cached_packages ||= fetch_packages([])
      end

      def import(full_name, short_name)
        return if full_name == short_name
        if short_name == '*'
          @search_packages << full_name.sub(/\.\*$/, '')
        else
          @imports[short_name] = full_name
        end
      end
    end
  end
end
