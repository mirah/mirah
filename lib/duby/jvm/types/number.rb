module Duby::JVM::Types
  class Number < PrimitiveType
    # The type returned by arithmetic operations with this type.
    def math_type
      self
    end
    
    def suffix
      ''
    end
    
    # Adds an intrinsic that delegates to an intrinsic in another primitive
    # type. That type must support promoting the "this" argument.
    def delegate_intrinsic(name, type, return_type)
      args = [type]
      delegate = type.intrinsics[name][args]
      add_method(name, args, return_type) do |compiler, call, expression|
        if expression
          delegate.call(compiler, call, expression)
        end
      end
    end
    
    def add_delegates(name, return_type)
      index = TYPE_ORDERING.index(math_type)
      larger_types = TYPE_ORDERING[index + 1, TYPE_ORDERING.size]
      larger_types.each do |type|
        delegate_intrinsic(name, type, return_type)
      end
    end

    # if_cmpxx for non-ints
    def jump_if(builder, op, label)
      builder.send "#{prefix}cmp#{suffix}"
      builder.send "if#{op}", label
    end

    def boolean_operator(name, op)
      add_method(name, [math_type], Boolean) do |compiler, call, expression|
        if expression
          # Promote the target or the argument if necessary
          convert_args(compiler,
                       [call.target, *call.parameters],
                       [math_type, math_type])
          compiler.method.op_to_bool do |label|
            jump_if(compiler.method, op, label)
          end
        end
      end
      add_delegates(name, Boolean)
    end
    
    def math_operator(name, op)
      add_method(name, [math_type], math_type) do |compiler, call, expression|
        if expression
          # Promote the target or the argument if necessary
          convert_args(compiler,
                       [call.target, *call.parameters],
                       [math_type, math_type])
          compiler.method.send "#{prefix}#{op}"
        end
      end
      add_delegates(name, math_type)
    end

    def unary_operator(name, op)
      add_method(name, [], math_type) do |compiler, call, expression|
        if expression
          call.target.compile(compiler, true)
          compiler.method.send("#{prefix}#{op}") if op
        end
      end
    end

    def add_intrinsics
      boolean_operator('<', :lt)
      boolean_operator('<=', :le)
      boolean_operator('==', :eq)
      boolean_operator('>=', :ge)
      boolean_operator('>', :gt)
      math_operator('+', :add)
      math_operator('-', :sub)
      math_operator('*', :mul)
      math_operator('/', :div)
      math_operator('%', :rem)
      unary_operator('-@', :neg)
      unary_operator('+@', nil)
    end

  end
end