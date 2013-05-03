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
import org.mirah.jvm.types.CallType
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
    @@log = Logger.getLogger(CallCompiler.class.getName)
  end
  def initialize(compiler:BaseCompiler, bytecode:Bytecode, position:Position, target:Node, name:String, args:NodeList, returnType:JVMType)
    initialize(compiler, bytecode, position, target, name, returnType)
    @args = Node[args.size]
    args.size.times {|i| @args[i] = args.get(i)}
  end
  def initialize(compiler:BaseCompiler, bytecode:Bytecode, position:Position, target:Node, name:String, args:List, returnType:JVMType)
    initialize(compiler, bytecode, position, target, name, returnType)
    @args = Node[args.size]
    args.toArray(@args)
  end
  
  # TODO: private
  def initialize(compiler:BaseCompiler, bytecode:Bytecode, position:Position, target:Node, name:String, returnType:JVMType)
    super(compiler.context)
    @compiler = compiler
    @method = bytecode
    @position = position
    @target = target
    @name = name
    @returnType = returnType
  end
  
  def compile(expression:boolean):void
    getMethod.accept(self, expression)
  end
  
  def getMethod
    @member ||= begin
      if @returnType.kind_of?(CallType)
        CallType(@returnType).member
      else
        argTypes = JVMType[@args.length]
        @args.length.times do |i|
          argTypes[i] = getInferredType(@args[i])
        end
        getInferredType(@target).getMethod(@name, Arrays.asList(argTypes))
      end
    end
  end
  
  def recordPosition:void
    @method.recordPosition(@position)
  end
  
  # private
  def compile(node:Node):void
    @compiler.visit(node, Boolean.TRUE)
  end
  
  def convertArgs(argumentTypes:List):void
    # TODO support required2 methods
    num_required = if @member.isVararg
      argumentTypes.size - 1
    else
      argumentTypes.size
    end
    num_required.times do |i|
      arg = @args[i]
      compile(arg)
      @method.convertValue(getInferredType(arg), JVMType(argumentTypes[i]))
    end
    if @member.isVararg
      createVarargArray(JVMType(argumentTypes[i]), num_required)
    end
  end
  
  def createVarargArray(arrayType:JVMType, offset:int):void
    vararg_items = @args.length - offset
    if vararg_items == 1 && arrayType.assignableFrom(getInferredType(@args[offset]))
      compile(@args[offset])
    else
      type = arrayType.getComponentType
      @method.push(vararg_items)
      @method.newArray(type.getAsmType)
      vararg_items.times do |i|
        @method.dup
        @method.push(i)
        arg = @args[offset + i]
        compile(arg)
        @method.convertValue(getInferredType(arg), type)
        @method.arrayStore(type.getAsmType)
      end
    end
  end

  def convertResult(returnedType:JVMType, expression:boolean):void
    if expression
      @method.convertValue(returnedType, @returnType)
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
    compile(@target)
    @method.convertValue(getInferredType(@target), type)
    convertArgs([type])
    recordPosition
    @method.math(op, asm_type)
    convertResult(type, expression)
  end
  
  def self.computeComparisonOp(name:String):int
    name = name.intern
    if name == '=='
      GeneratorAdapter.EQ
    elsif name == '>='
      GeneratorAdapter.GE
    elsif name == '>'
      GeneratorAdapter.GT
    elsif name == '<='
      GeneratorAdapter.LE
    elsif name == '<'
      GeneratorAdapter.LT
    elsif name == '!='
      GeneratorAdapter.NE
    else
      raise IllegalArgumentException, "Unsupported comparison #{name}"
    end
  end
  
  def compileComparisonValues(method:JVMMethod)
    type = method.declaringClass
    compile(@target)
    @method.convertValue(getInferredType(@target), type)
    convertArgs([type])
  end
  
  def visitComparison(method:JVMMethod, expression:boolean)
    compileComparisonValues(method)

    op = CallCompiler.computeComparisonOp(method.name)
    type = method.declaringClass
    ifTrue = @method.newLabel
    done = @method.newLabel
    @method.ifCmp(type.getAsmType, op, ifTrue)
    @method.push(0)
    @method.goTo(done)
    @method.mark(ifTrue)
    @method.push(1)
    @method.mark(done)
    @method.pop unless expression
  end
  
  def visitMethodCall(method:JVMMethod, expression:boolean)
    isVoid = method.returnType.getAsmType.getDescriptor.equals('V')
    compile(@target)
    returnType = method.returnType
    if expression && isVoid
      @method.dup
      returnType = getInferredType(@target)
    end
    convertArgs(method.argumentTypes)
    recordPosition
    if method.declaringClass.isInterface
      @method.invokeInterface(method.declaringClass.getAsmType, methodDescriptor(method))
    else
      @method.invokeVirtual(method.declaringClass.getAsmType, methodDescriptor(method))
    end
    convertResult(returnType, expression)
  end
  def visitStaticMethodCall(method:JVMMethod, expression:boolean)
    convertArgs(method.argumentTypes)
    recordPosition
    @method.invokeStatic(method.declaringClass.getAsmType, methodDescriptor(method))
    isVoid = method.returnType.getAsmType.getDescriptor.equals('V')
    if isVoid
      @method.pushNil if expression  # Should this be an error?
    else
      convertResult(method.returnType, expression)
    end
  end
  def visitConstructor(method:JVMMethod, expression:boolean)
    argTypes = method.argumentTypes
    klass = method.declaringClass.getAsmType
    asmArgs = Type[method.argumentTypes.size]
    asmArgs.length.times do |i|
      asmArgs[i] = JVMType(argTypes[i]).getAsmType
    end
    
    isDelegateCall = !expression && @target.kind_of?(ImplicitSelf) && @target.findAncestor(ConstructorDefinition.class) != nil
    if isDelegateCall
      @method.loadThis
    else
      @method.newInstance(klass)
      @method.dup if expression
    end
    convertArgs(argTypes)
    recordPosition
    desc = Method.new("<init>", Type.getType("V"), asmArgs)

    @method.invokeConstructor(method.declaringClass.getAsmType, desc)
  end
  def visitFieldAccess(method:JVMMethod, expression:boolean)
    compile(@target)
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
    compile(@target)
    compile(@args[0])
    @method.dupX1(getInferredType(@args[0])) if expression
    recordPosition
    @method.putField(method.declaringClass.getAsmType, method.name, method.returnType.getAsmType)
  end
  def visitStaticFieldAssign(method:JVMMethod, expression:boolean)
    compile(@args[0])
    @method.dup if expression
    recordPosition
    @method.putStatic(method.declaringClass.getAsmType, method.name, method.returnType.getAsmType)
  end
  def visitArrayAccess(method:JVMMethod, expression:boolean)
    compile(@target)
    convertArgs(method.argumentTypes)
    recordPosition
    @method.arrayLoad(method.returnType.getAsmType)
    convertResult(method.returnType, expression)
  end
  def visitArrayAssign(method:JVMMethod, expression:boolean)
    compile(@target)
    value_type = getInferredType(@args[1])
    convertArgs([method.argumentTypes[0], value_type])
    @method.dupX2(value_type) if expression
    @method.convertValue(value_type, JVMType(method.argumentTypes[1]))
    recordPosition
    @method.arrayStore(method.returnType.getAsmType)
  end
  def visitArrayLength(method:JVMMethod, expression:boolean)
    compile(@target)
    @method.arrayLength
  end
  
  def visitClassLiteral(method, expression)
    if expression
      recordPosition
      @method.push(getInferredType(@target).getAsmType)
    end
  end
  
  def visitInstanceof(method, expression)
    compile(@target)
    if expression
      @method.instanceOf(getInferredType(@args[0]).getAsmType)
    else
      @method.pop(getInferredType(@target))
    end
  end
  
  def visitIsNull(method, expression)
    compile(@target)
    if expression
      recordPosition
      nonNull = @method.newLabel
      done = @method.newLabel
      @method.ifNonNull(nonNull)
      @method.push(1)
      @method.goTo(done)
      @method.mark(nonNull)
      @method.push(0)
      @method.mark(done)
    else
      @method.pop
    end
  end
end