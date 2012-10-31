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
  class BooleanType < PrimitiveType
    def init_value(builder)
      builder.iconst_0
    end

    def prefix
      'i'
    end

    def box(builder)
      box_type = Mirah::AST::type(nil, 'java.lang.Boolean')
      builder.invokestatic box_type, "valueOf", [box_type, self]
    end

    def box_type
      @type_system.type(nil, 'java.lang.Boolean')
    end

    def add_intrinsics
      args = [math_type]
      add_method('==', args, ComparisonIntrinsic.new(self, '==', :eq, args))
      add_method('!=', args, ComparisonIntrinsic.new(self, '!=', :ne, args))
    end

    def math_type
      @type_system.type(nil, 'boolean')
    end

    # same as NumberType's
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

    # Same as IntegerType's
    # bools are ints for comparison purposes
    def jump_if(builder, op, label)
      builder.send "if_icmp#{op}", label
    end
  end
end
