module Mirah
  module JVM
    module Types
      class InterfaceDefinition < TypeDefinition
        def initialize(name, node)
          super(name, node)
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