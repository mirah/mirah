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
  end
end