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
    class StaticScope
      java_import 'java.util.LinkedHashMap'
      java_import 'org.mirah.typer.Scope'
      java_import 'org.mirah.typer.AssignableTypeFuture'
      java_import 'org.mirah.typer.LocalFuture'
      java_import 'org.mirah.typer.ErrorType'
      include Scope

      attr_reader :parent
      attr_writer :self_type, :self_node

      def initialize(node, scoper, parent=nil)
        @scope_node = node
        @vars = {}
        @var_types = {}
        @parent = parent
        @children = {}
        @imports = {}
        @search_packages = []
        @shadowed = {}
        @scoper = scoper
        @temps = Hash.new {|h,k| h[k] = -1}
        @package_block = nil
      end

      def context
        @scope_node
      end
      
      def to_s
        "#<StaticScope node=#{@scope_node.inspect}>"
      end

      def inspect
        result = "#<StaticScope\n  node=#{@scope_node.inspect}\n  "
        result << "parent=#{@parent}\n  " if @parent
        result << "vars=#{locals.inspect}\n  " if @vars.size > 0
        result << "shadowed=#{@shadowed.keys.inspect}\n  " if @shadowed.size > 0
        result << "temps=#{@temps.keys.inspect}\n  " if @temps.size > 0
        result << "package=#{@package}\n  " if @package
        result << "imports=#{@imports.inspect}\n  " if @imports.size > 0
        result << "search=#{@search_packages.inspect}\n  " if @search_packages.size > 0
        result << "self=#{@self_node.inspect}\n  " if @self_node
        if @self_type
          result << "self_type=#{@self_type}"
          if @self_type.isResolved
            result << " (#{@self_type.resolve.full_name})"
          end
          result << "\n  "
        end
        result << ">"
      end

      def toString; inspect; end

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

      def temp(name="tmp")
        "$#{name}$#{@temps[name] += 1}"
      end

      def local_type(name, position=nil)
        @var_types[name] ||= begin
          type = LocalFuture.new(name, position)
          type.onUpdate {|_, resolved| self << name unless resolved.isError}
          if parent && !shadowed?(name)
            # TODO what if a var of the same name is later declared in the parent scope?
            type.parent_set(parent.local_type(name, position))
          end
          type
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
        node = @scope_node
        return nil if node.nil? || node.parent.nil?
        @scoper.getScope(node)
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

      def binding_type
        if parent
          parent.binding_type
        else
          @binding_type
        end
      end

      def binding_type=(type)
        if parent
          parent.binding_type = type
        else
          @binding_type = type
        end
      end
      alias :binding_type_set :binding_type= 

      def has_binding?
        @binding_type != nil || (parent && parent.has_binding?)
      end

      def package
        @package || (outer_scope && outer_scope.package)
      end

      def package=(package)
        raise ArgumentError, "Package already set to #{@package.inspect}" if @package
        @package = package
        if @package_block
          @package_block.call
        end
      end

      def on_package_change(&block)
        @package_block = block
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
          @cached_packages = nil
        else
          @imports[short_name] = full_name
          @cached_imports = nil
        end
      end
      def selfType
        self_type
      end  # Should this be resolved?
      def selfType_set(type)
        self.self_type = type
      end
      def parent_set(scope)
        self.parent = scope
      end
      def package_set(package)
        self.package = package
      end
      def resetDefaultSelfNode
        self.self_node = :self
      end
    end
  end
end
