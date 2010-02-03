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

module Duby::JVM::Types
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

      add_macro('downto', Int, Duby::AST.block_type) do |transformer, call|
        Duby::AST::Loop.new(call.parent,
                            call.position, true, false) do |forloop|
          first, last = transformer.tmp, transformer.tmp
          init = transformer.eval("#{first} = 0; #{last} = 0;")
          init.children[-2].value = call.target
          init.children[-1].value = call.parameters[0]
          call.target.parent = init.children[-1]
          forloop.init << init

          var = call.block.args.args[0]
          if var
            forloop.pre << transformer.eval(
                "#{var.name} = #{first}", '', forloop, first, last)
          end
          forloop.post << transformer.eval("#{first} -= 1")
          call.block.body.parent = forloop if call.block.body
          [
            Duby::AST::Condition.new(forloop, call.position) do |c|
              [transformer.eval("#{first} >= #{last}",
                                '', forloop, first, last)]
            end,
            call.block.body
          ]
        end
      end
    end
  end
  
  class LongType < Number
    def prefix
      'l'
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
