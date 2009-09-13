module Duby::JVM::Types
  class BooleanType < PrimitiveType
    def init_value(builder)
      builder.iconst_0
    end
    
    def prefix
      'i'
    end
  end
end