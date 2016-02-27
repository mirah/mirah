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

package org.mirah.jvm.mirrors

import java.util.List
import org.mirah.util.Logger

import mirah.lang.ast.Noop

import org.objectweb.asm.Opcodes
import org.objectweb.asm.Type
import org.mirah.macros.anno.MacroDef
import org.mirah.macros.Macro
import org.mirah.typer.InlineCode
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.MemberKind
import org.mirah.util.Context

class MacroMember < Member
  def initialize(flags:int, klass:JVMType, name:String, argumentTypes:List,
                 returnType:InlineCode, kind:MemberKind)
    super(flags, klass, name, argumentTypes, nil, kind)
    @returnType = returnType
  end

  def asyncReturnType
    @returnType
  end

  def self.makeReturnType(klass:Class)
    InlineCode.new do |node, typer|
      constructor = klass.getDeclaredConstructors[0]
      macroimpl = Macro(constructor.newInstance(typer.macro_compiler, node))
      macroimpl.expand || Noop.new(node.position)
    end
  end

  def self.create(klass:Class, declaringClass:JVMType, context:Context)
    flags = Opcodes.ACC_PUBLIC
    macrodef = MacroDef(klass.getAnnotation(MacroDef.class))
    flags |= Opcodes.ACC_STATIC if macrodef.isStatic
    
    types = context[MirrorTypeSystem]
    
    # TODO support optional, rest args
    argumentTypes = []
    macrodef.arguments.required.each do |name|
      argumentTypes.add(types.loadMacroType(name))
    end
    vararg = macrodef.arguments.rest
    if vararg and vararg.trim.length > 0
      component_type = types.loadMacroType(vararg.trim)
      type = types.getArrayType(component_type)
      argumentTypes.add(type)
      flags |= Opcodes.ACC_VARARGS
    end

    kind = if macrodef.isStatic
      MemberKind.STATIC_METHOD
    else
      MemberKind.METHOD
    end
    
    MacroMember.new(flags, declaringClass, macrodef.name, argumentTypes,
                    makeReturnType(klass), kind)
  end
end