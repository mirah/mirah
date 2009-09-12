module Duby::JVM::Types
  Boolean = PrimitiveType.new(Java::boolean, java.lang.Boolean)
  Byte = IntegerType.new(Java::byte, java.lang.Byte)
  Char = IntegerType.new(Java::char, java.lang.Character)
  Short = IntegerType.new(Java::short, java.lang.Short)
  Int = IntegerType.new(Java::int, java.lang.Integer)
  Long = LongType.new(Java::long, java.lang.Long)
  Float = FloatType.new(Java::float, java.lang.Float)
  Double = DoubleType.new(Java::double, java.lang.Double)

  Object = Type.new(Java::JavaLang.Object)
  String = StringType.new(Java::JavaLang.String)

  Void = VoidType.new
  Null = NullType.new
  
  PrimitiveConversions = {
    Boolean => [Boolean],
    Byte => [Byte, Short, Int, Long, Float, Double],
    Short => [Short, Int, Long, Float, Double],
    Char => [Char, Int, Long, Float, Double],
    Int => [Int, Long, Float, Double],
    Long => [Long, Double],
    Float => [Float, Double],
    Double => [Double]
  }
end  