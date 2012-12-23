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

import java.util.Arrays
import java.util.List
import java.util.logging.Logger
import mirah.lang.ast.*
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.MemberVisitor
import org.mirah.util.Context

import org.jruby.org.objectweb.asm.ClassWriter
import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.Type
import org.jruby.org.objectweb.asm.commons.GeneratorAdapter
import org.jruby.org.objectweb.asm.commons.Method


class CallCompiler < BaseCompiler implements MemberVisitor
  def self.initialize:void
    @@log = Logger.getLogger(ClassCompiler.class.getName)
  end
  def initialize(compiler:MethodCompiler, position:Position, target:Node, name:String, args:NodeList)
    super(compiler.context)
    @compiler = compiler
    @method = compiler.bytecode
    @position = position
    @target = target
    @name = name
    @args = args
  end
  
  def compile(expression:boolean):void
    argTypes = JVMType[@args.size]
    @args.size.times do |i|
      argTypes[i] = getInferredType(@args.get(i))
    end
    method = getInferredType(@target).getMethod(@name, Arrays.asList(argTypes))
    method.accept(self, expression)
  end
  
  def recordPosition:void
    @compiler.recordPosition(@position)
  end
  
  def convertArgs(argumentTypes:List):void
    argumentTypes.size.times do |i|
      arg = @args.get(i)
      @compiler.compile(arg)
      @method.convertValue(getInferredType(arg), JVMType(argumentTypes[i]))
    end
  end

  def convertResult(returnedType:JVMType, expression:boolean):void
    if expression
      # TODO casts for generic method calls
    else
      @method.pop(returnedType)
    end
  end

  def computeMathOp(name:String):int
    name = name.intern
    if name == '+'
      GeneratorAdapter.ADD
    elsif name == '&'
      GeneratorAdapter.AND
    elsif name == '/'
      GeneratorAdapter.DIV
    elsif name == '*'
      GeneratorAdapter.MUL
    elsif name == '-@'
      GeneratorAdapter.NEG
    elsif name == '|'
      GeneratorAdapter.OR
    elsif name == '%'
      GeneratorAdapter.REM
    elsif name == '<<'
      GeneratorAdapter.SHL
    elsif name =='>>'
      GeneratorAdapter.SHR
    elsif name == '-'
      GeneratorAdapter.SUB
    elsif name == '>>>'
      GeneratorAdapter.USHR
    elsif name == '^'
      GeneratorAdapter.XOR
    else
      raise IllegalArgumentException, "Unsupported operator #{name}"
    end
  end

  def visitMath(method:JVMMethod, expression:boolean)
    op = computeMathOp(method.name)
    type = method.returnType
    asm_type = type.getAsmType
    @compiler.compile(@target)
    @method.convertValue(getInferredType(@target), type)
    convertArgs([type])
    recordPosition
    @method.math(op, asm_type)
    convertResult(type, expression)
  end
  
  def visitMethodCall(method:JVMMethod, expression:boolean)
    @compiler.compile(@target)
    convertArgs(method.argumentTypes)
    recordPosition
    @method.invokeVirtual(method.declaringClass.getAsmType, methodDescriptor(method))
    convertResult(method.returnType, expression)
  end
  def visitStaticMethodCall(method:JVMMethod, expression:boolean)
    convertArgs(method.argumentTypes)
    recordPosition
    @method.invokeStatic(method.declaringClass.getAsmType, methodDescriptor(method))    
    convertResult(method.returnType, expression)
  end
  def visitConstructor(method:JVMMethod, expression:boolean)
    argTypes = method.argumentTypes
    klass = method.declaringClass.getAsmType
    asmArgs = Type[method.argumentTypes.size]
    asmArgs.length.times do |i|
      asmArgs[i] = JVMType(argTypes[i]).getAsmType
    end

    @method.newInstance(klass)
    @method.dup if expression
    convertArgs(argTypes)
    recordPosition
    desc = Method.new("<init>", Type.getType("V"), asmArgs)

    @method.invokeConstructor(method.declaringClass.getAsmType, desc)
  end
  def visitFieldAccess(method:JVMMethod, expression:boolean)
    @compiler.compile(@target)
    if expression
      recordPosition
      @method.getField(method.declaringClass.getAsmType, method.name, method.returnType.getAsmType)
    else
      @method.pop
    end
  end
  def visitStaticFieldAccess(method:JVMMethod, expression:boolean)
    if expression
      recordPosition
      @method.getStatic(method.declaringClass.getAsmType, method.name, method.returnType.getAsmType)
    end
  end
  def visitFieldAssign(method:JVMMethod, expression:boolean)
    @compiler.compile(@target)
    @compiler.compile(@args.get(0))
    @method.dupX1(getInferredType(@args.get(0))) if expression
    @method.putField(method.declaringClass.getAsmType, method.name, method.returnType.getAsmType)
  end
  def visitStaticFieldAssign(method:JVMMethod, expression:boolean)
    @compiler.compile(@args.get(0))
    @method.dup if expression
    @method.putStatic(method.declaringClass.getAsmType, method.name, method.returnType.getAsmType)
  end
end