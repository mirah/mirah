module Mirah
  module JVM
    module Types
      class GenericType < Type
        java_import 'java.util.HashMap'
        java_import 'org.mirah.typer.GenericType'
        include GenericType

        attr_reader :ungeneric

        def initialize(ungeneric)
          super(ungeneric.type_system, ungeneric.name)
          @ungeneric = ungeneric
        end

        def basic_type
          @ungeneric.basic_type
        end

        def generic?
          true
        end

        def generic
          self
        end

        def ungeneric
          @ungeneric
        end

        def superclass
          @ungeneric.superclass.generic if @ungeneric.superclass
        end

        def interfaces(include_parent=true)
          []
        end

        def jvm_type
          @ungeneric.jvm_type
        end

        def inner_class?
          basic_type.inner_class?
        end

        def type_parameter_map
          unless @type_parameter_map
            @type_parameter_map = HashMap.new
          end
          @type_parameter_map
        end

        def assignable_from?(other)
          @ungeneric.assignable_from?(other)
        end

        def inspect(indent=0)
          "#{' ' * indent}#<#{self.class.name.split(/::/)[-1]} #{name} #{type_parameter_map}>"
        end
      end

      class TypeDefGeneric < GenericType
      end
    end
  end
end
