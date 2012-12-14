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
import mirah.lang.ast.*
import org.mirah.jvm.types.JVMType
import org.jruby.org.objectweb.asm.*
import org.jruby.org.objectweb.asm.Type as AsmType
import org.jruby.org.objectweb.asm.commons.GeneratorAdapter


import java.util.List

class MethodCompiler < BaseCompiler
  def self.initialize:void
    @@log = Logger.getLogger(ClassCompiler.class.getName)
  end
  def initialize(context:Context, flags:int, name:String)
    super(context)
    @flags = flags
    @name = name
  end
  
  def isVoid
    @descriptor.getDescriptor.endsWith(")V")
  end
  
  def compile(cv:ClassVisitor, mdef:MethodDefinition):void
    @builder = createBuilder(cv, mdef)
    context[AnnotationCompiler].compile(mdef.annotations, @builder)
    isExpression = isVoid() ? nil : Boolean.TRUE
    if (@flags & Opcodes.ACC_ABSTRACT) == 0
      visit(mdef.body, isExpression)
      @builder.returnValue
    end
    @builder.endMethod
  end

  def createBuilder(cv:ClassVisitor, mdef:MethodDefinition)
    type = getInferredType(mdef)
    returnType = JVMType(type.returnType)
    if @name.endsWith("init>")
      returnType = typer.type_system.getVoidType.resolve
    end
    @descriptor = methodDescriptor(@name, JVMType(returnType), type.parameterTypes)
    @selfType = JVMType(getScope(mdef).selfType.resolve)
    superclass = @selfType.superclass
    @superclass = if superclass
     superclass.getAsmType
    else
      AsmType.getType(Object.class)
    end
    GeneratorAdapter.new(@flags, @descriptor, nil, nil, cv)
  end
  
  def visitFixnum(node, expression)
    if expression
      isLong = "long".equals(getInferredType(node).name)
      if isLong
        @builder.push(node.value)
      else
        @builder.push(int(node.value))
      end
    end
  end
  
  def visitSuper(node, expression)
    @builder.loadThis
    @builder.loadArgs
    # This is a poorly named method, really it's invokeSpecial
    @builder.invokeConstructor(@superclass, @descriptor)
    if expression && isVoid
      @builder.loadThis
    elsif expression.nil? && !isVoid
      @builder.pop
    end
  end
end