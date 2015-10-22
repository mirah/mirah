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

import mirah.lang.ast.MacroDefinition
import mirah.lang.ast.MethodDefinition
import mirah.lang.ast.StaticMethodDefinition
import mirah.lang.ast.Position
import org.mirah.jvm.types.JVMType
import org.mirah.typer.MethodType

import javax.tools.Diagnostic.Kind

class MethodState
  def initialize(macrodef:MacroDefinition)
    if macrodef.arguments
      @num_args = macrodef.arguments.required_size
      @num_args += 1 if macrodef.arguments.block
    else
      @num_args = 0
    end
    @name = macrodef.name.identifier
    @position = macrodef.name.position
    @signature = nil
    @static    = macrodef.isStatic
  end

  def initialize(method:MethodDefinition, type:MethodType)
    @name = method.name.identifier
    @position = method.name.position
    @num_args = type.parameterTypes.size
    @returnType = JVMType(type.returnType)
    signature = StringBuilder.new
    type.parameterTypes.each do |t:JVMType|
      signature.append(t.getAsmType.getDescriptor)
    end
    @signature = signature.toString
    @static    = method.kind_of?(StaticMethodDefinition) # "def self.initialize" is supported. "class << self; def initialize" is not supported, but this is currently broken, anyway.
  end

  def conflictsWith(other:MethodState):Kind
    return nil unless @name.equals(other.name)
    return nil unless @num_args == other.num_args
    if self.isMacro && !other.isMacro 
      other.conflictsWith(self)
    elsif !self.isMacro && other.isMacro
      if @num_args != 0
        # At least one of these is a macro, so it's hard to tell if
        # the arguments will actually conflict. Just emit a warning.
        Kind.WARNING
      else
        Kind.ERROR
      end
    elsif self.isMacro && other.isMacro
      if @num_args == 0
        if self.static ^ other.static 
          # Macros are allowed to have overlapping no-arg signatures if exactly one of them is static.
          nil
        else
          Kind.ERROR
        end
      else
        # Since both of these are macros, it's hard to tell if their arguments will conflict.
        Kind.WARNING
      end
    else
      # Two methods
      if @signature.equals(other.signature)
        if self.static==other.static || !name.equals("initialize")
          # TODO, generate bridge methods automatically and make this an error
          Kind.WARNING
        else # methods differ in their staticity, but the name is "initialize". As these methods are compiled to "<init>" and "<clinit>", there is actually no conflict.
          nil
        end
      else
        nil
      end
    end
  end

  attr_accessor num_args:int, name:String, position:Position, returnType:JVMType, static:boolean
  attr_accessor signature:String

  def toString
    "#{@signature ? 'method' : 'macro'} #{@name}"
  end
  
  def isMacro
    @signature==nil
  end
end