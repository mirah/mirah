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

import java.util.LinkedHashMap
import java.util.LinkedList

import org.jruby.org.objectweb.asm.ClassVisitor
import org.jruby.org.objectweb.asm.Label
import org.jruby.org.objectweb.asm.MethodVisitor
import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.Type
import org.jruby.org.objectweb.asm.commons.GeneratorAdapter
import org.jruby.org.objectweb.asm.commons.Method

import mirah.lang.ast.Position
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.JVMType

# Helper class for generating jvm bytecode.
class Bytecode < GeneratorAdapter
  class LocalInfo
    def initialize(name:String, index:int, type:Type, scopeStart:Label, scopeEnd:Label)
      @name = name
      @index = index
      @type = type
      @scopeStart = scopeStart
      @scopeEnd = scopeEnd
    end
    def declare(visitor:MethodVisitor):void
      visitor.visitLocalVariable(@name, @type.getDescriptor, nil, @scopeStart, @scopeEnd, @index)
    end
    def toString
      "<Local #{index} (#{name}:#{type.getDescriptor})>"
    end
    attr_reader name:String, index:int, type:Type, scopeStart:Label, scopeEnd:Label
  end
  
  def initialize(flags:int, method:Method, klass:ClassVisitor)
    super(Opcodes.ASM4,
          klass.visitMethod(flags, method.getName, method.getDescriptor, nil, nil),
          flags, method.getName, method.getDescriptor)
    @endLabel = newLabel
    @locals = LinkedHashMap.new
    @nextLocal = (flags & Opcodes.ACC_STATIC == Opcodes.ACC_STATIC) ? 0 : 1
    @firstLocal = @nextLocal
  end

  def arguments
    args = LinkedList.new
    @locals.values.each do |info|
      if LocalInfo(info).index < @firstLocal
        args.add(info)
      else
        break
      end
    end
    return args
  end
  
  def declareArg(name:String, type:JVMType)
    declareLocal(name, type.getAsmType)
    @firstLocal = @nextLocal
  end
  
  def declareLocal(name:String, type:JVMType):LocalInfo
    declareLocal(name, type.getAsmType)
  end
  
  def declareLocal(name:String, type:Type):LocalInfo
    LocalInfo(@locals[name] ||= begin
      index = @nextLocal
      @nextLocal += type.getSize
      LocalInfo.new(name, index, type, mark(), @endLabel)
    end)
  end

  def storeLocal(name:String, type:JVMType):void
    storeLocal(name, type.getAsmType)
  end
  
  def storeLocal(name:String, type:Type):void
    info = declareLocal(name, type)
    visitVarInsn(info.type.getOpcode(Opcodes.ISTORE), info.index)
  end
  
  def loadLocal(name:String):void
    info = LocalInfo(@locals[name])
    visitVarInsn(info.type.getOpcode(Opcodes.ILOAD), info.index)
  end

  def endMethod:void
    mark(@endLabel)
    @locals.values.each do |info|
      LocalInfo(info).declare(self)
    end
    super
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
  
  def invokeSpecial(type:Type, method:Method):void
    invokeConstructor(type, method)
  end
end