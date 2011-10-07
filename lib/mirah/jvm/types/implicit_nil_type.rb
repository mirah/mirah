module Mirah
  module JVM
    module Types
      class ImplicitNilType < Type
        def initialize(types)
          super(types, types.get_mirror('java.lang.Object'))
        end

        def to_s
          "Type(implicit_nil)"
        end

        def widen(other)
          other
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