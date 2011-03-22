module Mirah
  module JVM
    module Types
      class PrimitiveType < Type
        def initialize(type, wrapper)
          @wrapper = wrapper
          super(type)
        end

        def primitive?
          true
        end

        def primitive_type
          @wrapper::TYPE
        end

        def newarray(method)
          method.send "new#{name}array"
        end

        def interfaces
          []
        end

        def convertible_to?(type)
          return true if type == self
          widening_conversions = WIDENING_CONVERSIONS[self]
          widening_conversions && widening_conversions.include?(type)
        end

        def superclass
          nil
        end
      end
    end
  end
end