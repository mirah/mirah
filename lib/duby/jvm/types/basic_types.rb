module Duby::JVM::Types
  Boolean = BooleanType.new('boolean', java.lang.Boolean)
  Byte = IntegerType.new('byte', java.lang.Byte)
  Char = IntegerType.new('char', java.lang.Character)
  Short = IntegerType.new('short', java.lang.Short)
  Int = IntegerType.new('int', java.lang.Integer)
  Long = LongType.new('long', java.lang.Long)
  Float = FloatType.new('float', java.lang.Float)
  Double = DoubleType.new('double', java.lang.Double)

  # TODO these shouldn't be constants. They should be loaded from
  # the compilation class path.
  Object = Type.new(BiteScript::ASM::ClassMirror.load('java.lang.Object'))
  String = StringType.new(
      BiteScript::ASM::ClassMirror.load('java.lang.String'))
  Iterable = IterableType.new(
          BiteScript::ASM::ClassMirror.load('java.lang.Iterable'))

  Void = VoidType.new
  Null = NullType.new

  WIDENING_CONVERSIONS = {
    Byte => [Byte, Short, Int, Long, Float, Double],
    Short => [Short, Int, Long, Float, Double],
    Char => [Char, Int, Long, Float, Double],
    Int => [Int, Long, Float, Double],
    Long => [Long, Float, Double],
    Float => [Float, Double],
    Double => [Double]
  }
  TYPE_ORDERING = [Byte, Short, Int, Long, Float, Double]
end