module Duby::JVM::Types
  class BooleanType < PrimitiveType
    def init_value(builder)
      builder.iconst_0
    end

    def prefix
      'i'
    end

    def box(builder)
      box_type = Duby::AST::type('java.lang.Boolean')
      builder.invokestatic box_type, "valueOf", [box_type, self]
    end

  end
end