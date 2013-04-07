# Copyright (c) 2010-2013 The Mirah project authors. All Rights Reserved.
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

module Mirah
  module JVM
    module Types
      class PrimitiveType < Type
        WIDENING_CONVERSIONS = {
          'byte' => ['byte', 'short', 'int', 'long', 'float', 'double', 'java.lang.Byte', 'java.lang.Object'],
          'short' => ['short', 'int', 'long', 'float', 'double', 'java.lang.Short', 'java.lang.Object'],
          'char' => ['char', 'int', 'long', 'float', 'double', 'java.lang.Character', 'java.lang.Object'],
          'int' => ['int', 'long', 'float', 'double','java.lang.Integer', 'java.lang.Object'],
          'long' => ['long', 'float', 'double', 'java.lang.Long', 'java.lang.Object'],
          'float' => ['float', 'double', 'java.lang.Float', 'java.lang.Object'],
          'double' => ['double', 'java.lang.Double', 'java.lang.Object']
        }

        def initialize(types, type, wrapper)
          @wrapper = wrapper
          super(types, type)
        end

        def primitive?
          true
        end

        def primitive_type
          @wrapper::TYPE
        end

        def newarray(method)
          method.send "new#{name}array"
        end

        def interfaces(include_parent=true)
          []
        end

        def convertible_to?(type)
          return true if type == self
          return false if type.array?
          widening_conversions = WIDENING_CONVERSIONS[self.name]
          widening_conversions && widening_conversions.include?(type.name)
        end

        def superclass
          nil
        end

        def wrapper_name
          @wrapper.java_class.name
        end

        def box(builder)
          builder.invokestatic box_type, "valueOf", [box_type, self]
        end
      end
    end
  end
end
