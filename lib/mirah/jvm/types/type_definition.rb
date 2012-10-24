module Mirah
  module JVM
    module Types
      class TypeDefinition < Type
        java_import 'mirah.lang.ast.InterfaceDeclaration'
        attr_accessor :node, :scope

        def initialize(types, scope, name, node)
          raise ArgumentError, "Bad name #{name}" if name[0,1] == '.'
          raise ArgumentError, "Bad name #{name}" if name.include? ?/
          @type_system = types
          @scope = scope
          @name = name
          @node = node
          raise ArgumentError, "Bad type #{name}" if self.name =~ /Java::/
        end

        def name
          if @type
            @type.name.tr('/', '.')
          else
            if !@name.include?(?.) && scope.package
              "#{scope.package}.#{@name}"
            else
              @name
            end
          end
        end

        def superclass
          if node && node.superclass
            @type_system.get(scope, node.superclass.typeref).resolve
          else
            @type_system.type(nil, 'java.lang.Object')
          end
        end

        def interfaces(include_parent=true)
          if node
            node.interfaces.map {|n| @type_system.get(scope, n.typeref).resolve}
          else
            []
          end
        end

        def define(builder)
          class_name = name.tr('.', '/')
          abstract = node && node.kind_of?(InterfaceDeclaration)  #node.abstract
          @type ||= builder.define_class(
              class_name,
              :visibility => :public,
              :abstract => abstract,
              :superclass => superclass,
              :interfaces => interfaces)
        end

        def meta
          @meta ||= TypeDefMeta.new(self)
        end
      end

      class TypeDefMeta < MetaType
      end
    end
  end
end
