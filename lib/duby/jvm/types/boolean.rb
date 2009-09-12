module Duby::JVM::Types
  class BooleanType < PrimitiveType
    def load(builder, index)
      builder.iload(index)
    end
  end
end