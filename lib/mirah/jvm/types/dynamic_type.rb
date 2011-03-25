module Mirah
  module JVM
    module Types
      class DynamicType < Type
        ObjectType = Type.new(BiteScript::ASM::ClassMirror.for_name('java.lang.Object'))

        def initialize
          # For naming, bytecode purposes, we are an Object
          @name = "java.lang.Object"
        end

        def basic_type
          self
        end

        def is_parent(other)
          ObjectType.assignable_from?(other)
        end

        def assignable_from?(other)
          ObjectType.assignable_from?(other)
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
          ObjectType.superclass
        end
        
        def interfaces
          ObjectType.interfaces
        end
      end
    end
  end
end