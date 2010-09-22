module Duby
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
        while scope.parent && scope.parent.include?(name)
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
        @parent = parent
        @children = {}
        @imports = LinkedHashMap.new
      end

      def <<(name)
        @vars[name] = true
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
            factory = Duby::AST.type_factory
            if factory
              factory.declare_type(name)
            else
              Duby::AST::TypeReference.new(name, false, false)
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
        @package || scope_node.scope.package
      end

      def fetch_imports(map)
        if scope_node.scope
          scope_node.scope.fetch_imports(map)
        end
        map.addAll(@imports)
        map
      end

      def imports
        @cached_imports ||= begin
          map = LinkedHashMap.new
          fetch_imports(map)
        end
      end

      def import(full_name, short_name)
        @imports[full_name] = short_name
      end
    end
  end
end
