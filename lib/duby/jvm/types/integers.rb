module Duby::JVM::Types
  class IntegerType < PrimitiveType
    def literal(builder, value)
      builder.push_int(value)
    end
    
    def load(builder, index)
      builder.iload(index)
    end
    
    def widen(builder, type)
      case type
      when Byte, Short, Int
        # do nothing
      when Long
        builder.i2l
      when Float
        builder.i2f
      when Double
        builder.i2d
      else
        raise ArgumentError, "Invalid widening conversion from #{name} to #{type}"
      end
    end
  end
  
  class LongType < PrimitiveType
    def literal(builder, value)
      builder.push_long(value)
    end
    
    def load(builder, index)
      builder.lload(index)
    end

    def widen(builder, type)
      case type
      when Long
        # do nothing
      when Float
        builder.l2f
      when Double
        builder.l2d
      else
        raise ArgumentError, "Invalid widening conversion from Int to #{type}"
      end
    end
  end
end