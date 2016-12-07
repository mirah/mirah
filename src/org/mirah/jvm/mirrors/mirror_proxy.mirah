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

import java.util.Collections
import javax.lang.model.type.ArrayType
import javax.lang.model.type.DeclaredType
import javax.lang.model.type.ErrorType
import javax.lang.model.type.NoType
import javax.lang.model.type.NullType
import javax.lang.model.type.PrimitiveType
import javax.lang.model.type.TypeKind
import javax.lang.model.type.TypeMirror

import javax.lang.model.type.TypeVariable as TypeVariableModel
import javax.lang.model.type.WildcardType
import mirah.lang.ast.Position
import org.mirah.jvm.types.CallType
import org.mirah.jvm.types.GenericMethod
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.JVMField
import org.mirah.jvm.types.JVMType
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.TypeFuture
import org.mirah.jvm.mirrors.generics.Wildcard
import org.mirah.jvm.mirrors.generics.TypeVariable

# Simple proxy for a MirrorType.
# The typer compares types using ==, but sometimes we need to
# change a Mirror in an incompatible way. We can return a new
# proxy for the same Mirror, and the typer will treat this as
# a new type.
class MirrorProxy implements MirrorType,
                             PrimitiveType,
                             DeclaredType,
                             ArrayType,
                             NoType,
                             ErrorType,
                             NullType,
                             TypeVariableModel,
                             WildcardType,
                             DeclaredMirrorType

  def self.create(type:MirrorType)
    if type.kind_of? MirrorProxy
      type
    else
      MirrorProxy.new type
    end
  end

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
  def isFullyResolved():boolean
    @target.isFullyResolved()
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
  def hasMember(name)
    @target.hasMember(name)
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
  def getComponentType:MirrorType
    if @target.getComponentType.kind_of? MirrorType
      # unchecked typecheck
      MirrorType(Object(@target.getComponentType))
    else
      nil
    end
  end
  # FIXME: Manual bridge methods
  def getComponentType:TypeMirror
    if @target.getComponentType.kind_of? TypeMirror
      # unchecked typecheck
      TypeMirror(Object(@target.getComponentType))
    else
      nil
    end
  end
  def getComponentType:JVMType
    @target.getComponentType
  end
  def hasStaticField(name)
    @target.hasStaticField(name)
  end
  def getMethod(name, params)
    @target.getMethod(name, params)
  end
  def getDeclaredFields:JVMField[]
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

  def isSameType(other)
    @target && @target.isSameType(other)
  end

  def isInterface
    @target.isInterface
  end

  def directSupertypes
    @target.directSupertypes
  end

  def isSupertypeOf(other)
    @target.isSupertypeOf(other)
  end

  # TypeMirror methods
  def getKind
    if @target
      @target.getKind
    else
      TypeKind.ERROR
    end
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
    if @target.kind_of? DeclaredType
      # unchecked typecheck
      DeclaredType(Object(@target)).getTypeArguments
    else
      nil
    end
  end
  def getLowerBound
    if @target.kind_of? TypeVariableModel
      # unchecked typecheck
      TypeVariableModel(Object(@target)).getLowerBound
    else
      nil
    end
  end
  def getUpperBound
    if @target.kind_of? TypeVariableModel
      # unchecked typecheck
      TypeVariableModel(Object(@target)).getUpperBound
    else
      nil
    end
  end
  def getExtendsBound
    if @target.kind_of? WildcardType
      # unchecked typecheck
      WildcardType(Object(@target)).getExtendsBound
    else
      nil
    end
  end
  def getSuperBound
    if @target.kind_of? WildcardType
      # unchecked typecheck
      WildcardType(Object(@target)).getSuperBound
    else
      nil
    end
  end
  def erasure
    e = @target.erasure
    if e == @target
      self
    else
      e
    end
  end

  def signature
    if target.kind_of?(DeclaredMirrorType)
      DeclaredMirrorType(@target).signature
    else
      nil
    end
  end

  def ensure_linked
    if @target.kind_of?(DeclaredMirrorType)
      DeclaredMirrorType(@target).ensure_linked
    end
  end

  def getTypeVariableMap
    if @target.kind_of?(DeclaredMirrorType)
      DeclaredMirrorType(@target).getTypeVariableMap
    else
      Collections.emptyMap
    end
  end
end

class MirrorFuture < BaseTypeFuture
  def initialize(type:MirrorType, position:Position=nil)
    super(position)
    @type = type
    type.onIncompatibleChange do
      self.maybeResolved
    end
    maybeResolved
  end
  
  def maybeResolved
    if checkResolved
      forgetType
      @mirror_proxy = MirrorProxy.create(type)
      resolved(@mirror_proxy)
    end
  end

  def checkResolved
    direct_supertypes = @type.directSupertypes
    direct_supertypes.size.times do |i|
      direct_supertype = direct_supertypes[i]
      if direct_supertype.kind_of?(MirrorProxy)
        if !MirrorProxy(direct_supertype).isFullyResolved
          return false
        end
      elsif direct_supertype.kind_of?(ErrorType)
        return false
      end
    end
    true
  end
  
  def isResolved
    super && @type.isFullyResolved
  end
  
  # MirrorFuture does not support the generic contract that the inferred type is always the resolved type.
  # The represented type is always set. However, resolution may happen only when also the parent types are resolved.
  # Hence, if we were not implementing our own #peekInferredType, the supermethod would return nil when we could actually return @type.
  def peekInferredType
    @type
  end
end

class ResolvedCall < MirrorProxy implements CallType
  def initialize(target:MirrorType, method:JVMMethod)
    super(ResolvedCall.expressionType(target, method))
    @member = method
  end

  def self.create(target:MirrorType, method:JVMMethod)
    ResolvedCall.new(target, method)
  end

  def self.expressionType(target:MirrorType, method:JVMMethod):MirrorType
    return_type = if method.kind_of?(GenericMethod)
      MirrorType(GenericMethod(method).genericReturnType)
    else
      MirrorType(method.returnType)
    end
    if "V".equals(return_type.getAsmType.getDescriptor)
      target
    else
      return_type
    end
  end

  attr_reader member:JVMMethod

  def hashCode
    target.hashCode
  end

  def equals(other)
    import static org.mirah.util.Comparisons.*
    if areSame(self, other)
      true
    elsif other.kind_of?(ResolvedCall)
      rc = ResolvedCall(other)
      target.equals(rc.target) && @member.equals(rc.member)
    else
      false
    end
  end
end