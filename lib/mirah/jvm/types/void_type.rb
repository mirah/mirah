module Mirah
  module JVM
    module Types
      class VoidType < PrimitiveType
        def initialize
          super('void', Java::JavaLang::Void)
        end

        def void?
          true
        end

        def return(builder)
          builder.returnvoid
        end
      end
    end
  end
end