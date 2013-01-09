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

import org.jruby.org.objectweb.asm.ClassVisitor
import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.Type
import org.jruby.org.objectweb.asm.commons.GeneratorAdapter
import org.jruby.org.objectweb.asm.commons.Method

import mirah.lang.ast.Position
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.JVMType

# Helper class for generating jvm bytecode.
class Bytecode < GeneratorAdapter
  def initialize(flags:int, method:Method, klass:ClassVisitor)
    super(Opcodes.ASM4,
          klass.visitMethod(flags, method.getName, method.getDescriptor, nil, nil),
          flags, method.getName, method.getDescriptor)
  end
  
  def recordPosition(position:Position)
    visitLineNumber(position.startLine, mark) if position
  end
  
  def pushNil:void
    push(String(nil))
  end
  
  def pop(type:JVMType)
    size = type.getAsmType.getSize
    if size == 1
      pop
    elsif size == 2
      pop2
    end
  end
  
  def dup(type:JVMType)
    size = type.getAsmType.getSize
    if size == 1
      dup
    elsif size == 2
      dup2
    end
  end
  
  def dupX1(type:JVMType)
    size = type.getAsmType.getSize
    if size == 1
      dupX1
    elsif size == 2
      dup2X1
    end
  end
  
  def dupX2(type:JVMType)
    size = type.getAsmType.getSize
    if size == 1
      dupX2
    elsif size == 2
      dup2X2
    end
  end

  def convertValue(currentType:JVMType, wantedType:JVMType):void
    unless currentType.equals(wantedType)
      if currentType.isPrimitive && wantedType.isPrimitive
        cast(currentType.getAsmType, wantedType.getAsmType)
      elsif currentType.isPrimitive
        # TODO make sure types match
        box(currentType.getAsmType)
      elsif wantedType.isPrimitive
        # TODO make sure types match
        unbox(currentType.getAsmType)
      elsif !wantedType.assignableFrom(currentType)
        checkCast(wantedType.getAsmType)
      end
    end
  end
end