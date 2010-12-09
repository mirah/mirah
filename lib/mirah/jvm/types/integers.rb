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

class BiteScript::MethodBuilder
  def inot
    iconst_m1
    ixor
  end
  
  def lnot
    # TODO would any of these be faster?
    #   iconst_m1; i2l
    #   lconst_1; lneg
    ldc_long(-1)
    ixor
  end
end

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
    
    def widen(builder, type)
      case type
      when Byte, Short, Int
        # do nothing
      when Long
        builder.i2l
      when Float
        builder.i2f
      when Double
        builder.i2d
      else
        raise ArgumentError, "Invalid widening conversion from #{name} to #{type}"
      end
    end
    
    def prefix
      'i'
    end
    
    def math_type
      Int
    end

    def box_type
      java.lang.Integer
    end

    def jump_if(builder, op, label)
      builder.send "if_icmp#{op}", label
    end

    def build_loop(parent, position, duby, block, first_value,
                   last_value, ascending, inclusive)
      if ascending
        comparison = "<"
        op = "+="
      else
        comparison = ">"
        op = "-="
      end
      comparison << "=" if inclusive
      forloop = Mirah::AST::Loop.new(parent, position, true, false) do |forloop|
        first, last = duby.tmp, duby.tmp
        init = duby.eval("#{first} = 0; #{last} = 0;")
        init.children[-2].value = first_value
        init.children[-1].value = last_value
        forloop.init << init

        var = (block.args.args || [])[0]
        if var
          forloop.pre << duby.eval(
              "#{var.name} = #{first}", '', forloop, first, last)
        end
        forloop.post << duby.eval("#{first} #{op} 1")
        [
          Mirah::AST::Condition.new(forloop, position) do |c|
            [duby.eval("#{first} #{comparison} #{last}",
                       '', forloop, first, last)]
          end,
          nil
        ]
      end
      forloop.body = block.body
      forloop
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

      add_macro('downto', Int, Mirah::AST.block_type) do |transformer, call|
        build_loop(call.parent, call.position, transformer,
                   call.block, call.target, call.parameters[0], false, true)
      end
      add_macro('upto', Int, Mirah::AST.block_type) do |transformer, call|
        build_loop(call.parent, call.position, transformer,
                   call.block, call.target, call.parameters[0], true, true)
      end
      add_macro('times', Mirah::AST.block_type) do |transformer, call|
        build_loop(call.parent, call.position, transformer,
                   call.block, Mirah::AST::fixnum(nil, call.position, 0),
                   call.target, true, false)
      end
    end
  end

  class LongType < Number
    def prefix
      'l'
    end

    def math_type
      Long
    end

    def box_type
      java.lang.Long
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

    def widen(builder, type)
      case type
      when Long
        # do nothing
      when Float
        builder.l2f
      when Double
        builder.l2d
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
