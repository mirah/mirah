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
  class FloatType < Number
    def prefix
      'f'
    end

    def math_type
      @type_system.type(nil, 'float')
    end

    def box_type
      @type_system.type(nil, 'java.lang.Float')
    end

    def suffix
      'g'
    end

    def init_value(builder)
      builder.fconst_0
    end

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

    def compile_widen(builder, type)
      case type.name
      when 'float'
        # Do nothing
      when 'double'
        builder.f2d
      when @wrapper.java_class.name, 'java.lang.Object'
        builder.invokestatic @wrapper, "valueOf", [@wrapper, builder.send(name)]
      else
        raise ArgumentError, "Invalid widening conversion from float to #{type}"
      end
    end
  end

  class DoubleType < FloatType
    def prefix
      'd'
    end

    def math_type
      @type_system.type(nil, 'double')
    end

    def box_type
      @type_system.type(nil, 'java.lang.Double')
    end

    def wide?
      true
    end

    def init_value(builder)
      builder.dconst_0
    end

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

    def compile_widen(builder, type)
      case type.name
      when 'double'
      when @wrapper.java_class.name, 'java.lang.Object'
        builder.invokestatic @wrapper, "valueOf", [@wrapper, builder.send(name)]
      else
        raise ArgumentError, "Invalid widening conversion from double to #{type}"
      end
    end
  end
end
