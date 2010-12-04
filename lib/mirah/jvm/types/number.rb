module Mirah::JVM::Types
  class ComparisonIntrinsic < Intrinsic
    attr_reader :name, :op
    def initialize(type, name, op, args)
      super(type, name, args, Boolean) do; end
      @type = type
      @op = op
    end

    def call(compiler, call, expression)
      if expression
        @type.compile_boolean_operator(compiler, op, false, call, nil)
      end
    end

    def jump_if(compiler, call, label)
      @type.compile_boolean_operator(compiler, @op, false, call, label)
    end

    def jump_if_not(compiler, call, label)
      @type.compile_boolean_operator(compiler, @op, true, call, label)
    end
  end

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
      if delegate.kind_of?(ComparisonIntrinsic)
        add_method(name, args, ComparisonIntrinsic.new(type, name, delegate.op, args))
      else
        add_method(name, args, return_type) do |compiler, call, expression|
          if expression
            delegate.call(compiler, call, expression)
          end
        end
      end
    end
    
    def add_delegates(name, return_type = nil)
      index = TYPE_ORDERING.index(math_type)
      larger_types = TYPE_ORDERING[index + 1, TYPE_ORDERING.size]
      larger_types.each do |type|
        delegate_intrinsic(name, type, return_type || type)
      end
    end

    # if_cmpxx for non-ints
    def jump_if(builder, op, label)
      builder.send "#{prefix}cmp#{suffix}"
      builder.send "if#{op}", label
    end

    def boolean_operator(name, op)
      args = [math_type]
      add_method(name, args, ComparisonIntrinsic.new(self, name, op, args))
      add_delegates(name, Boolean)
    end

    def invert_op(op)
      inverted = {
        :lt => :ge,
        :le => :gt,
        :eq => :ne,
        :ne => :eq,
        :gt => :le,
        :ge => :lt
      }[op]
      raise "Can't invert #{op}." unless inverted
      inverted
    end

    def compile_boolean_operator(compiler, op, negated, call, label)
      # Promote the target or the argument if necessary
      convert_args(compiler,
                   [call.target, *call.parameters],
                   [math_type, math_type])
      if negated
        op = invert_op(op)
      end
      if label
        jump_if(compiler.method, op, label)
      else
        compiler.method.op_to_bool do |label|
          jump_if(compiler.method, op, label)
        end
      end
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
      add_delegates(name)
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
      boolean_operator('!=', :ne)
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

    def box(builder)
      builder.invokestatic box_type, "valueOf", [box_type, math_type]
    end
  end
end