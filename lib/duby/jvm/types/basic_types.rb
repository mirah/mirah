module Duby::JVM::Types
  Boolean = PrimitiveType.new(Java::boolean, java.lang.Boolean)
  Byte = PrimitiveType.new(Java::byte, java.lang.Byte)
  Char = PrimitiveType.new(Java::char, java.lang.Character)
  Short = PrimitiveType.new(Java::short, java.lang.Short)
  Int = PrimitiveType.new(Java::int, java.lang.Integer)
  Long = PrimitiveType.new(Java::long, java.lang.Long)
  Float = PrimitiveType.new(Java::float, java.lang.Float)
  Double = PrimitiveType.new(Java::double, java.lang.Double)

  Object = Type.new(Java::JavaLang.Object)
  String = StringType.new(Java::JavaLang.String)

  Void = VoidType.new
  Null = NullType.new
  
  PrimitiveConversions = {
    Boolean => [Boolean],
    Byte => [Byte, Short, Char, Int, Long, Float, Double],
    Short => [Short, Int, Long, Float, Double],
    Char => [Char, Int, Long, Float, Double],
    Int => [Int, Long, Float, Double],
    Long => [Long, Double],
    Float => [Float, Double],
    Double => [Double]
  }
end  