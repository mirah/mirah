# Copyright (c) 2012 The Mirah project authors. All Rights Reserved.
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

package org.mirah.jvm.compiler

import java.util.logging.Logger
import org.jruby.org.objectweb.asm.Label
import org.jruby.org.objectweb.asm.Type
import org.jruby.org.objectweb.asm.commons.GeneratorAdapter

import mirah.lang.ast.Node
import org.mirah.jvm.types.MemberKind

class ConditionCompiler < BaseCompiler
  import static org.mirah.jvm.types.JVMTypeUtils.*

  def self.initialize:void
    @@log = Logger.getLogger(ConditionCompiler.class.getName)
    @@NEGATED_OPS = {
      '==' => '!=',
      '!=' => '==',
      '<' => '>=',
      '>' => '<=',
      '<=' => '>',
      '>=' => '<'
    }
  end
  def initialize(method:BaseCompiler, bytecode:Bytecode)
    super(method.context)
    @method = method
    @bytecode = bytecode
    @negated = false
  end
  
  def negate
    @negated = ! @negated
  end
  
  def compile(node:Node, label:Label)
    visit(node, Boolean.TRUE)
    if @op
      doComparison(label)
    else
      doJump(label)
    end
  end

  def doJump(label:Label)
    if isPrimitive(@type)
      if "float".equals(@type.name)
        @bytecode.push(float(0))
        @op = "=="
        doComparison(label)
      elsif "double".equals(@type.name)
        @bytecode.push(double(0))
        @op = "=="
        doComparison(label)
      elsif "long".equals(@type.name)
        @bytecode.push(long(0))
        @op = "=="
        doComparison(label)
      else
        mode = @negated ? GeneratorAdapter.EQ : GeneratorAdapter.NE
        @bytecode.ifZCmp(mode, label)
      end
    else
      if @negated
        @bytecode.ifNull(label)
      else
        @bytecode.ifNonNull(label)
      end
    end
  end

  def doComparison(label:Label)
    op = @negated ? @@NEGATED_OPS[@op] : @op
    @bytecode.ifCmp(@type.getAsmType, CallCompiler.computeComparisonOp(String(op)), @negated, label)
  end
  
  def visitNot(node, expression)
    negate
    visit(node.value, expression)
  end
  
  def visitCall(node, expression)
    call = CallCompiler.new(@method, @bytecode, node.position, node.target, node.name.identifier, node.parameters, getInferredType(node))
    member = call.getMethod
    kind = member.kind
    if MemberKind.COMPARISON_OP == kind
      # TODO optimize comparison with 0, null
      call.compileComparisonValues(member)
      @op = member.name
      @type = member.declaringClass
    elsif MemberKind.IS_NULL == kind
      negate
      @method.visit(node.target, Boolean.TRUE)
      @type = getInferredType(node.target)
    else
      call.compile(true)
      @type = getInferredType(node)
    end
  end
  
  def defaultNode(node, expression)
    @method.visit(node, expression)
    @type = getInferredType(node)
  end
end
