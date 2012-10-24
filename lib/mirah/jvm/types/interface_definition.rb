module Mirah
  module JVM
    module Types
      class InterfaceDefinition < TypeDefinition
        def initialize(types, scope, name, node)
          super(types, scope, name, node)
        end

        def define(builder)
          class_name = @name.tr('.', '/')
          @type ||= builder.public_interface(class_name, *interfaces)
        end

        def interface?
          true
        end
      end
    end
  end
end
