module Duby::JVM::Types
  Boolean = PrimitiveType.new(Java::boolean, java.lang.Boolean)
  Byte = PrimitiveType.new(Java::byte, java.lang.Byte)
  Char = PrimitiveType.new(Java::Char, java.lang.Character)
  Short = PrimitiveType.new(Java::Short, java.lang.Short)
  Int = PrimitiveType.new(Java::Int, java.lang.Integer)
  Long = PrimitiveType.new(Java::Long, java.lang.Long)
  Float = PrimitiveType.new(Java::Float, java.lang.Float)
  Double = PrimitiveType.new(Java::Double, java.lang.Double)

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