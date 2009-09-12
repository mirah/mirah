module Duby::JVM::Types
  class IntegerType < PrimitiveType
    def literal(builder, value)
      builder.push_int(value)
    end
  end
  
  class LongType < PrimitiveType
    def literal(builder, value)
      builder.push_long(value)
    end
  end
end