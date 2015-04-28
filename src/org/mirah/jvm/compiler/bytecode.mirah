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

import org.objectweb.asm.ClassVisitor
import org.objectweb.asm.Label
import org.objectweb.asm.MethodVisitor
import org.objectweb.asm.Opcodes
import org.objectweb.asm.Type
import org.objectweb.asm.commons.GeneratorAdapter
import org.objectweb.asm.commons.Method

import mirah.lang.ast.CodeSource
import mirah.lang.ast.Position
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.JVMType

# Helper class for generating jvm bytecode.
class Bytecode < GeneratorAdapter
  import static org.mirah.jvm.types.JVMTypeUtils.*

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
  
  def initialize(flags:int, method:Method, klass:ClassVisitor, codesource:CodeSource)
    super(Opcodes.ASM4,
          MethodVisitor(@mv = LocalInitializerAdapter.new(klass.visitMethod(
              flags, method.getName, method.getDescriptor, nil, nil),
              flags, method.getDescriptor)),
          flags, method.getName, method.getDescriptor)
    @endLabel = newLabel
    @locals = LinkedHashMap.new
    @nextLocal = 0
    @firstLocal = @nextLocal
    @codesource = codesource
    @currentLine = -1
    @flags = flags
  end

  def instruction_count
    @mv.instruction_count
  end

  def arguments
    args = LinkedList.new
    @locals.values.each do |info: LocalInfo|
      if info.index < @firstLocal
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
    raise "missing local #{name} in list #{@locals.keySet}" if info.nil?
    visitVarInsn(info.type.getOpcode(Opcodes.ILOAD), info.index)
  end

  def endMethod:void
    if 0 == @flags & (Opcodes.ACC_NATIVE | Opcodes.ACC_ABSTRACT)
      mark(@endLabel)
      @locals.values.each do |info|
        LocalInfo(info).declare(self)
      end
    end
    super
  end
  
  def recordPosition(position:Position, atEnd:boolean=false)
    if position && position.source == @codesource
      line = atEnd ? position.endLine : position.startLine
      if line != @currentLine
        visitLineNumber(line, mark)
        @currentLine = line
      end
    end
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
      if isPrimitive(currentType) && isPrimitive(wantedType)
        cast(currentType.getAsmType, wantedType.getAsmType)
      elsif isPrimitive(currentType)
        # TODO make sure types match
        box(currentType.getAsmType)
      elsif isPrimitive(wantedType)
        # TODO make sure types match
        unbox(wantedType.getAsmType)
      elsif !wantedType.assignableFrom(currentType)
        checkCast(wantedType.getAsmType)
      end
    end
  end
  
  def invokeSpecial(type:Type, method:Method):void
    invokeConstructor(type, method)
  end

  def ifCmp(type:Type, mode:int, negated:boolean, label:Label):void
    sort = type.getSort
    # We often negate conditions so that we can generate code in an order that
    # makes sense. If this is a floating point type, we also need to make sure
    # comparisons with NaN get negated.
    negated_float = (negated & ((sort == Type.FLOAT) | (sort == Type.DOUBLE)))
    if negated_float
      greater = (mode == GeneratorAdapter.GE || mode == GeneratorAdapter.GT)
      if sort == Type.FLOAT
        @mv.visitInsn(greater ? Opcodes.FCMPG : Opcodes.FCMPL)
      else
        @mv.visitInsn(greater ? Opcodes.DCMPG : Opcodes.DCMPL)
      end
      @mv.visitJumpInsn(mode, label)
    else
      ifCmp(type, mode, label)
    end
  end
end