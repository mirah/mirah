# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
# All contributing project authors may be found in the NOTICE file.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Mirah::JVM::Types
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
  ClassType = Type.new(BiteScript::ASM::ClassMirror.load('java.lang.Class'))
  String = StringType.new(
      BiteScript::ASM::ClassMirror.load('java.lang.String'))
  Iterable = IterableType.new(
          BiteScript::ASM::ClassMirror.load('java.lang.Iterable'))

  Void = VoidType.new
  Unreachable = UnreachableType.new
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