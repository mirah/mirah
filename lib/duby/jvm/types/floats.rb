module Duby::JVM::Types
  class FloatType < PrimitiveType
    def literal(builder, value)
      case value
      when 0.0
        builder.fconst_0
      when 1.0
        builder.fconst_1
      when 2.0
        builder.fconst_2
      else
        builder.ldc_float(value)
      end
    end
    
    def load(builder, index)
      builder.fload(index)
    end

    def widen(builder, type)
      case type
      when Float
        # Do nothing
      when Double
        builder.f2d
      else
        raise ArgumentError, "Invalid widening conversion from Int to #{type}"
      end
    end
  end
  
  class DoubleType < PrimitiveType
    def literal(builder, value)
      case value
      when 0.0
        builder.dconst_0
      when 1.0
        builder.dconst_1
      else
        builder.ldc_double(value)
      end
    end
    
    def load(builder, index)
      builder.dload(index)
    end
    
    def widen(builder, type)
      if type != Double
        raise ArgumentError, "Invalid widening conversion from Int to #{type}"
      end
    end
  end
end