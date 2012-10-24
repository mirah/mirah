module Mirah
  module JVM
    module Types
      class PrimitiveType < Type
        WIDENING_CONVERSIONS = {
          'byte' => ['byte', 'short', 'int', 'long', 'float', 'double'],
          'short' => ['short', 'int', 'long', 'float', 'double'],
          'char' => ['char', 'int', 'long', 'float', 'double'],
          'int' => ['int', 'long', 'float', 'double'],
          'long' => ['long', 'float', 'double'],
          'float' => ['float', 'double'],
          'double' => ['double']
        }

        def initialize(types, type, wrapper)
          @wrapper = wrapper
          super(types, type)
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

        def interfaces(include_parent=true)
          []
        end

        def convertible_to?(type)
          return true if type == self
          widening_conversions = WIDENING_CONVERSIONS[self.name]
          widening_conversions && widening_conversions.include?(type.name)
        end

        def superclass
          nil
        end
      end
    end
  end
end
