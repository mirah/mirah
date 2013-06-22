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

import javax.lang.model.type.DeclaredType
import javax.lang.model.type.NoType
import javax.lang.model.type.PrimitiveType
import javax.lang.model.type.TypeKind
import mirah.lang.ast.Position
import org.mirah.jvm.types.CallType
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.JVMType
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.TypeFuture

# Simple proxy for a MirrorType.
# The typer compares types using ==, but sometimes we need to
# change a Mirror in an incompatible way. We can return a new
# proxy for the same Mirror, and the typer will treat this as
# a new type.
class MirrorProxy implements MirrorType, PrimitiveType, DeclaredType
  def initialize(type:MirrorType)
    @target = type
  end

  attr_accessor target:MirrorType

  def notifyOfIncompatibleChange:void
    @target.notifyOfIncompatibleChange
  end
  def onIncompatibleChange(listener):void
    @target.onIncompatibleChange(listener)
  end
  def getDeclaredMethods(name)
    @target.getDeclaredMethods(name)
  end
  def getAllDeclaredMethods
    @target.getAllDeclaredMethods
  end
  def addMethodListener(name, listener):void
    @target.addMethodListener(name, listener)
  end
  def invalidateMethod(name):void
    @target.invalidateMethod(name)
  end
  def add(member):void
    @target.add(member)
  end
  def superclass
    @target.superclass
  end
  def getAsmType
    @target.getAsmType
  end
  def flags
    @target.flags
  end
  def interfaces:TypeFuture[]
    @target.interfaces
  end
  def retention
    @target.retention
  end
  def getComponentType
    @target.getComponentType
  end
  def hasStaticField(name)
    @target.hasStaticField(name)
  end
  def getMethod(name, params)
    @target.getMethod(name, params)
  end
  def getDeclaredFields:JVMMethod[]
    @target.getDeclaredFields
  end
  def getDeclaredField(name)
    @target.getDeclaredField(name)
  end
  def widen(other)
    @target.widen(other)
  end
  def assignableFrom(other)
    @target.assignableFrom(other)
  end
  def name
    @target.name
  end
  def isMeta
    @target.isMeta
  end
  def isBlock
    @target.isBlock
  end
  def isError
    @target.isError
  end
  def matchesAnything
    @target.matchesAnything
  end
  def toString
    @target.toString
  end
  def unmeta
    if @target.isMeta
      @target.unmeta
    else
      self
    end
  end
  def box
    @target.box
  end
  def unbox
    @target.unbox
  end
  def declareField(field)
    @target.declareField(field)
  end

  # TypeMirror methods
  def getKind
    @target.getKind
  end
  def accept(v, p)
    k = getKind
    if k == TypeKind.DECLARED
      v.visitDeclared(self, p)
    else
      v.visitPrimitive(self, p)
    end
  end
  def getTypeArguments
    DeclaredType(@target).getTypeArguments
  end
end

class MirrorFuture < BaseTypeFuture
  def initialize(type:MirrorType, position:Position=nil)
    super(position)
    resolved(type)
    future = self
    type.onIncompatibleChange do
      future.resolved(MirrorProxy.new(type))
    end
  end
end

class ResolvedCall < MirrorProxy implements CallType
  def initialize(target:MirrorType, method:JVMMethod)
    super(ResolvedCall.expressionType(target, method))
    @member = method
  end

  def self.expressionType(target:MirrorType, method:JVMMethod):MirrorType
    if "V".equals(method.returnType.getAsmType.getDescriptor)
      target
    else
      MirrorType(method.returnType)
    end
  end

  attr_reader member:JVMMethod
end