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

require 'mirah/jvm/types/bitescript_ext'

module Mirah::JVM::Types
  class IntegerType < Number
    def literal(builder, value)
      builder.push_int(value)
    end

    def init_value(builder)
      builder.iconst_0
    end

    def load(builder, index)
      builder.iload(index)
    end

    def compile_widen(builder, type)
      case type.name
      when 'byte', 'short', 'int'
        # do nothing
      when 'long'
        builder.i2l
      when 'float'
        builder.i2f
      when 'double'
        builder.i2d
      when @wrapper.java_class.name, 'java.lang.Object'
        builder.invokestatic @wrapper, "valueOf", [@wrapper, builder.send(name)]
      else
        raise ArgumentError, "Invalid widening conversion from #{name} to #{type}"
      end
    end

    def prefix
      'i'
    end

    def math_type
      @type_system.type(nil, 'int')
    end

    def box_type
      @type_system.type(nil, 'java.lang.Integer')
    end

    def jump_if(builder, op, label)
      builder.send "if_icmp#{op}", label
    end

    def add_intrinsics
      super
      math_operator('<<', 'shl')
      math_operator('>>', 'shr')
      math_operator('>>>', 'ushr')
      math_operator('|', 'or')
      math_operator('&', 'and')
      math_operator('^', 'xor')
      unary_operator('~', 'not')
    end
  end

  class LongType < Number
    def prefix
      'l'
    end

    def math_type
      @type_system.type(nil, 'long')
    end

    def box_type
      @type_system.type(nil, 'java.lang.Long')
    end

    def literal(builder, value)
      builder.ldc_long(value)
    end

    def init_value(builder)
      builder.lconst_0
    end

    def wide?
      true
    end

    def compile_widen(builder, type)
      case type.name
      when 'long'
        # do nothing
      when 'float'
        builder.l2f
      when 'double'
        builder.l2d
      when @wrapper.java_class.name, 'java.lang.Object'
        builder.invokestatic @wrapper, "valueOf", [@wrapper, builder.send(name)]
      else
        raise ArgumentError, "Invalid widening conversion from Int to #{type}"
      end
    end

    def add_intrinsics
      super
      math_operator('<<', 'shl')
      math_operator('>>', 'shr')
      math_operator('>>>', 'ushr')
      math_operator('|', 'or')
      math_operator('&', 'and')
      math_operator('^', 'xor')
      unary_operator('~', 'not')
    end
  end
end
