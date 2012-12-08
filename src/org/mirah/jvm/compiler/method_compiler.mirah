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
  
  def compile(cv:ClassVisitor, mdef:MethodDefinition):void
    @builder = createBuilder(cv, mdef)
    context[AnnotationCompiler].compile(mdef.annotations, @builder)
    isVoid = @descriptor.getDescriptor.endsWith(")V") ? Boolean.TRUE : nil
    if (@flags & Opcodes.ACC_ABSTRACT) == 0
      visit(mdef.body, isVoid)
    end
    @builder.visitEnd
  end

  def createBuilder(cv:ClassVisitor, mdef:MethodDefinition)
    type = getInferredType(mdef)
    @descriptor = methodDescriptor(@name, JVMType(type.returnType), type.parameterTypes)
    GeneratorAdapter.new(@flags, @descriptor, nil, nil, cv)
  end
end