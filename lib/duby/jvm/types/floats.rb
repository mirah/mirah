module Duby::JVM::Types
  class FloatType < Number
    def prefix
      'f'
    end

    def math_type
      Float
    end

    def box_type
      java.lang.Float
    end
    
    def suffix
      'g'
    end

    def init_value(builder)
      builder.fconst_0
    end

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
    
    def widen(builder, type)
      case type
      when Float
        # Do nothing
      when Double
        builder.f2d
      else
        raise ArgumentError, "Invalid widening conversion from float to #{type}"
      end
    end
  end
  
  class DoubleType < FloatType
    def prefix
      'd'
    end

    def math_type
      Double
    end

    def box_type
      java.lang.Double
    end

    def wide?
      true
    end

    def init_value(builder)
      builder.dconst_0
    end

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
    
    def widen(builder, type)
      if type != Double
        raise ArgumentError, "Invalid widening conversion from double to #{type}"
      end
    end
  end
end