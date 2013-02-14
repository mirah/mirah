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

import java.util.ArrayList
import java.util.logging.Logger

import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.Type

import org.mirah.typer.AssignableTypeFuture
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.ErrorType
import org.mirah.typer.MethodFuture
import org.mirah.typer.ResolvedType
import org.mirah.typer.TypeFuture
import org.mirah.typer.TypeSystem

import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.MemberKind

class MirrorTypeSystem implements TypeSystem
  def initialize
    @futures = {}
    @object_future = wrap(Type.getType('Ljava/lang/Object;'))
    @object = BaseType(@object_future.resolve)
    @object.add(Member.new(Opcodes.ACC_PUBLIC, @object, "<init>", [], JVMType(getVoidType.resolve), MemberKind.CONSTRUCTOR))
    @main_type = wrap(Type.getType('LFooBar;'))
  end

  def self.initialize:void
    @@log = Logger.getLogger(MirrorTypeSystem.class.getName)
  end

  def getSuperClass(type)
    future = BaseTypeFuture.new
    future.position = BaseTypeFuture(type).position if type.kind_of?(BaseTypeFuture)
    type.onUpdate do |x, resolved|
      if resolved.isError
        future.resolved(resolved)
      else
        future.resolved(JVMType(resolved).superclass)
      end
    end
    future
  end

  def getMainType(scope, script)
    @main_type
  end

  def addDefaultImports(scope)
  end
  
  def getFixnumType(value)
    wrap(Type.getType("I"))
  end
  
  def getVoidType
    @void ||= wrap(Type.getType("V"))
  end
  
  def getImplicitNilType
    getVoidType
  end
  
  def getMethodDefType(target, name, argTypes, declaredReturnType, position)
    resolvedArgs = ArrayList.new
    argTypes.each {|arg| resolvedArgs.add(TypeFuture(arg).resolve)}
    returnType = AssignableTypeFuture.new(position).resolved(ErrorType.new([
      ["Cannot determing return type for method #{target}.#{name}#{argTypes}", position]]))
    returnType.declare(declaredReturnType, position) if declaredReturnType
    @method = MethodFuture.new(name, resolvedArgs, returnType, false, position)
  end

  def getMethodType(call)
    @method || BaseTypeFuture.new(call.position)
  end

  def getMetaType(type:ResolvedType):ResolvedType
    if type.isError
      type
    else
      jvmType = BaseType(type)
      if jvmType.isMeta
        jvmType
      else
        MetaType.new(jvmType)
      end
    end
  end

  def getMetaType(type:TypeFuture):TypeFuture
    future = BaseTypeFuture.new
    types = TypeSystem(self)
    type.onUpdate do |x, resolved|
      future.resolved(types.getMetaType(resolved))
    end
    future
  end
  
  def getLocalType(scope, name, position)
    @local ||= AssignableTypeFuture.new(position)
  end

  def defineType(scope, node, name, superclass, interfaces)
    future = BaseTypeFuture.new(node.position)
    type = Type.getObjectType(name.replace(?., ?/))
    object_type = @object
    TypeFuture(@futures[type.getClassName] ||= begin
      superclass ||= @object_future
      isDefined = false
      superclass.onUpdate do |x, resolved|
        unless isDefined
          jvm_superclass = resolved.isError ? object_type : JVMType(resolved)
          future.resolved(BaseType.new(type, Opcodes.ACC_PUBLIC, jvm_superclass))
        end
      end
      future
    end)
  end

  def get(scope, typeref)
    TypeFuture(@futures[typeref.name])
  end

  def wrap(type:Type):TypeFuture
    TypeFuture(@futures[type.getClassName] ||= begin
      jvmtype = BaseType.new(type, Opcodes.ACC_PUBLIC, @object)
      BaseTypeFuture.new.resolved(jvmtype)
    end)
  end
end