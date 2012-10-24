module Mirah
  module JVM
    module Types
      class UnreachableType < Type
        def initialize
          super('java.lang.Object')
        end

        def to_s
          "Type(null)"
        end

        def unreachable?
          true
        end

        def compatible?(other)
          true
        end

        def assignable_from?(other)
          true
        end
      end
    end
  end
end
