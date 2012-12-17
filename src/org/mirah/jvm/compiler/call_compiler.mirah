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
import java.util.logging.Logger
import mirah.lang.ast.*
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.MemberVisitor
import org.mirah.util.Context

import org.jruby.org.objectweb.asm.ClassWriter
import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.commons.GeneratorAdapter


class CallCompiler < BaseCompiler implements MemberVisitor
  def self.initialize:void
    @@log = Logger.getLogger(ClassCompiler.class.getName)
  end
  def initialize(compiler:MethodCompiler, position:Position, target:Node, name:String, args:NodeList)
    super(compiler.context)
    @compiler = compiler
    @method = compiler.method
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
  
  def recordPosition
    @compiler.recordPosition(@position)
  end
  
  def visitMath(op:int, type:JVMType, expression:boolean)
    asm_type = type.getAsmType
    @compiler.compile(@target)
    @method.cast(getInferredType(@target).getAsmType, asm_type)
    value = @args.get(0)
    @compiler.compile(value)
    @method.cast(getInferredType(value).getAsmType, asm_type)
    recordPosition
    @method.math(op, asm_type)
    @method.pop unless expression
  end
end