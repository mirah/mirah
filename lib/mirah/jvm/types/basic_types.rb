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
  class TypeFactory
    def create_basic_types
      @known_types.update(
        'boolean' => BooleanType.new(self, 'boolean', java.lang.Boolean),
        'byte' => IntegerType.new(self, 'byte', java.lang.Byte),
        'char' => IntegerType.new(self, 'char', java.lang.Character),
        'short' => IntegerType.new(self, 'short', java.lang.Short),
        'int' => IntegerType.new(self, 'int', java.lang.Integer),
        'long' => LongType.new(self, 'long', java.lang.Long),
        'float' => FloatType.new(self, 'float', java.lang.Float),
        'double' => DoubleType.new(self, 'double', java.lang.Double)
      )
      @known_types['fixnum'] = @known_types['int']
      @known_types['Object'] = type(nil, 'java.lang.Object')
      @known_types['string'] = @known_types['String'] = @known_types['java.lang.String'] =
          StringType.new(self, get_mirror('java.lang.String'))
      type(nil, 'java.lang.Class')
      @known_types['Iterable'] = @known_types['java.lang.Iterable'] =
          IterableType.new(self, get_mirror('java.lang.Iterable'))
      @known_types['void'] = VoidType.new(self)
      @known_types['null'] = NullType.new(self)
      @known_types['implicit_nil'] = ImplicitNilType.new(self)
      @known_types['dynamic'] = DynamicType.new(self)
    end
  end
end
