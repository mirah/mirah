module Mirah
  module JVM
    module Types
      class NullType < Type
        def initialize(types)
          super(types, types.get_mirror('java.lang.Object'))
        end

        def to_s
          "Type(null)"
        end

        def null?
          true
        end

        def compatible?(other)
          assignable_from(other)
        end

        def assignable_from?(other)
          if other.respond_to?(:primitive?)
            !other.primitive?
          else
            other.matchesAnything
          end
        end
      end
    end
  end
end