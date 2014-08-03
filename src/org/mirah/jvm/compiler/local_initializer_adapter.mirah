# Copyright (c) 2013 The Mirah project authors. All Rights Reserved.
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

import java.util.List
import java.util.ArrayList
import org.objectweb.asm.MethodVisitor
import org.objectweb.asm.Opcodes
import org.objectweb.asm.tree.*
import org.objectweb.asm.tree.analysis.*

class FlexibleFrame < Frame
  def initialize
    super(0, 0)
    @locals = []
    @stack = []
    @top = 0
  end

  def initialize(other:Frame)
    initialize()
    init(other)
  end

  def init(other)
    @locals = []
    @stack = []
    @top = other.getStackSize
    other.getLocals.times do |i|
      setLocal(i, other.getLocal(i))
    end
    @top.times do |i|
      setStack(i, other.getStack(i))
    end
    self
  end

  def resize(list:List, size:int):void
    while list.size < size
      list.add(BasicValue.UNINITIALIZED_VALUE)
    end
  end
  
  def getLocals
    @locals.size
  end

  def getLocal(i)
    if i >= @locals.size
      BasicValue.UNINITIALIZED_VALUE
    else
      Value(@locals.get(i))
    end
  end

  def setLocal(i, v)
    resize(@locals, i + 1)
    @locals.set(i, v)
  end

  def getStackSize
    @top
  end

  def getStack(i)
    if i >= @stack.size
      BasicValue.UNINITIALIZED_VALUE
    else
      Value(@stack.get(i))
    end
  end

  def setStack(i:int, v:Value):void
    resize(@stack, i + 1)
    @stack.set(i, v)
  end

  def clearStack
    @top = 0
  end

  def pop
    @top -= 1
    getStack(@top)
  end

  def push(v)
    setStack(@top, v)
    @top += 1
  end

  def merge(frame:Frame, interpreter:Interpreter)
    changes = false
    @locals.size.times do |i|
      v = interpreter.merge(getLocal(i), frame.getLocal(i))
      unless v.equals(getLocal(i))
        setLocal(i, v)
        changes = true
      end
    end
    @stack.size.times do |i|
      v = interpreter.merge(getStack(i), frame.getStack(i))
      unless v.equals(getStack(i))
        setStack(i, v)
        changes = true
      end
    end
    changes
  end
end

class FlexibleAnalyzer < Analyzer
  def initialize(interpreter:Interpreter)
    super
  end

  def newFrame(locals, stack)
    FlexibleFrame.new
  end

  def newFrame(src)
    FlexibleFrame.new(src)
  end
end

class LocalInitializerAdapter < MethodVisitor
  def initialize(mv:MethodVisitor, flags:int, desc:String)
    super(Opcodes.ASM4,
          MethodVisitor(@node = MethodNode.new(
              Opcodes.ASM4, flags, nil, desc, nil, nil)))
    @mv = mv
  end

  def instruction_count
    @node.instructions.size
  end

  def visitEnd
    super
    fixUnitializedLocals
    @node.accept(@mv)
  end

  def fixUnitializedLocals
    analyzer = FlexibleAnalyzer.new(BasicInterpreter.new)
    analyzer.analyze("Foo", @node)
    inits = InsnList.new
    already_initialized = {}
    
    array = @node.instructions.toArray
    frames = analyzer.getFrames
    
    # Search for accesses to an unitialized local variable.
    array.length.times do |i|
      opcode = array[i].getOpcode
      if opcode >= Opcodes.ILOAD && opcode <= Opcodes.ALOAD
        var = VarInsnNode(array[i]).var
        frame = frames[i]
        next if frame.nil?
        next unless frame.getLocal(var) == BasicValue.UNINITIALIZED_VALUE

        unless already_initialized.containsKey(var)
          # We found one, now create an initializer for the correct type.
          already_initialized[var] = nil
          value = if opcode == Opcodes.ILOAD
            Opcodes.ICONST_0
          elsif opcode == Opcodes.LLOAD
            Opcodes.LCONST_0
          elsif opcode == Opcodes.FLOAD
            Opcodes.FCONST_0
          elsif opcode == Opcodes.DLOAD
            Opcodes.DCONST_0
          else
            Opcodes.ACONST_NULL
          end
          inits.add(InsnNode.new(value))
          opcode += (Opcodes.ISTORE - Opcodes.ILOAD)
          inits.add(VarInsnNode.new(opcode, var))
        end
      end
    end
    if inits.size > 0
      @node.instructions.insert(inits)
    end
  end
end