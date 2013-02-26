module Mirah
  module JVM
    module Types
      class DynamicType < Type
        def initialize(types)
          # For naming, bytecode purposes, we are an Object
          super(types, "java.lang.Object")
          @object_type ||= types.type(nil, 'java.lang.Object')
        end

        def basic_type
          self
        end

        def is_parent(other)
          @object_type.assignable_from?(other)
        end

        def assignable_from?(other)
          @object_type.assignable_from?(other)
        end

        def jvm_type
          java.lang.Object
        end

        def full_name
          "dynamic"
        end

        def dynamic?
          true
        end

        def superclass
          @object_type
        end

        def interfaces(include_parent=true)
          @object_type.interfaces
        end
      end
    end
  end
end
