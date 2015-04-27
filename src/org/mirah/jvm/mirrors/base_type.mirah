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

import java.util.logging.Logger

import java.util.Collections
import java.util.ArrayList
import java.util.HashSet
import java.util.LinkedList
import java.util.List
import java.util.Map
import java.util.Set
import javax.lang.model.type.DeclaredType
import javax.lang.model.type.NoType
import javax.lang.model.type.TypeKind
import javax.lang.model.type.TypeMirror

import mirah.objectweb.asm.Opcodes
import mirah.objectweb.asm.Type
import org.mirah.jvm.mirrors.generics.LubFinder
import org.mirah.jvm.model.IntersectionType
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMTypeUtils
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.MemberKind
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.ErrorType
import org.mirah.typer.ResolvedType
import org.mirah.typer.TypeFuture
import org.mirah.util.Context

interface MethodListener
  def methodChanged(klass:JVMType, name:String):void; end
end

interface MirrorType < JVMType, TypeMirror
  def notifyOfIncompatibleChange:void; end
  def onIncompatibleChange(listener:Runnable):void; end
  def getDeclaredMethods(name:String):List; end  # List<Member>
  def getAllDeclaredMethods:List; end
  def addMethodListener(name:String, listener:MethodListener):void; end
  def invalidateMethod(name:String):void; end
  def add(member:JVMMethod):void; end
  def declareField(field:JVMMethod):void; end
  def unmeta:MirrorType; end
  def isSameType(other:MirrorType):boolean; end
  def isSupertypeOf(other:MirrorType):boolean; end
  def directSupertypes:List; end
  def erasure:TypeMirror; end
end

interface DeclaredMirrorType < MirrorType, DeclaredType
  def link:void; end
  def signature:String; end
  def getTypeVariableMap:Map; end
end

# package_private
class BaseType implements MirrorType, DeclaredType, MethodListener

  def self.initialize:void
    @@kind_map = {
      Z: TypeKind.BOOLEAN,
      B: TypeKind.BYTE,
      C: TypeKind.CHAR,
      D: TypeKind.DOUBLE,
      F: TypeKind.FLOAT,
      I: TypeKind.INT,
      J: TypeKind.LONG,
      S: TypeKind.SHORT,
      V: TypeKind.VOID,
    }
  end

  def initialize(context:Context, type:Type, flags:int, superclass:JVMType)
    initialize(context, type.getClassName, type, flags, superclass)
  end

  def initialize(context:Context, name:String, type:Type, flags:int, superclass:JVMType)
    @context = context
    @name = name
    @type = type
    @flags = flags
    @superclass = superclass
    @members = {}
    @method_listeners = {}
    @compatibility_listeners = []
  end

  attr_reader superclass:JVMType, name:String, type:Type, flags:int, context:Context

  def notifyOfIncompatibleChange:void
    @cached_supertypes = List(nil)
    listeners = ArrayList.new(@compatibility_listeners)
    listeners.each do |l: Runnable|
      l.run()
    end
    methods = HashSet.new(@method_listeners.keySet)
    methods.each do |n|
      invalidateMethod(String(n))
    end
  end

  def onIncompatibleChange(listener:Runnable)
    @compatibility_listeners.add(listener)
  end

  def assignableFrom(other)
    MethodLookup.isSubTypeWithConversion(other, self)
  end

  def widen(other)
    if assignableFrom(other)
      self
    elsif other.assignableFrom(self)
      other
    elsif self.box
      self.box.widen(other)
    elsif other.kind_of?(MirrorType) && MirrorType(other).box
      widen(MirrorType(other).box)
    else
      # This may spread intersection types to places java wouldn't allow them.
      # Do we care?
      lub = MirrorType(Object(LubFinder.new(@context).leastUpperBound([self, other])))
      lub || ErrorType.new([["Incompatible types #{self} and #{other}."]])
    end
  end

  def isMeta:boolean; false; end
  def isBlock:boolean; false; end
  def isError:boolean; false; end
  def matchesAnything:boolean; false; end

  def getAsmType:Type; @type; end

  def isInterface:boolean
    0 != (self.flags & Opcodes.ACC_INTERFACE)
  end

  def retention:String; nil; end

  def getKind
    TypeKind.DECLARED
  end

  def accept(v, p)
    v.visitDeclared(self, p)
  end

  def getTypeArguments
    Collections.emptyList
  end

  def getComponentType:JVMType; nil; end

  def hasStaticField(name:String):boolean
    field = getDeclaredField(name)
    field && field.kind.name.startsWith("STATIC_")
  end

  def getDeclaredMethods(name:String)
    @methods_loaded ||= load_methods
    # TODO: should this filter out fields?
    List(@members[name]) || Collections.emptyList
  end

  def getAllDeclaredMethods
    @methods_loaded ||= load_methods
    methods = ArrayList.new
    @members.values.each do |list: List|
      list.each do |m: Member|
        if m.kind != MemberKind.CLASS_LITERAL
          methods.add(m)
        end
      end
    end
    methods
  end

  def interfaces:TypeFuture[]
    TypeFuture[0]
  end

  def getDeclaredFields:JVMMethod[]
    return JVMMethod[0]
  end
  def getDeclaredField(name:String):JVMMethod; nil; end

  def add(member:JVMMethod):void
    members = List(@members[member.name] ||= LinkedList.new)
    members.add(Member(member))
    invalidateMethod(member.name)
  end

  def addMethodListener(name:String, listener:MethodListener)
    @methods_loaded ||= load_methods
    listeners = Set(@method_listeners[name] ||= HashSet.new)
    listeners.add(listener)
    parent = superclass
    if parent && parent.kind_of?(MirrorType)
      MirrorType(parent).addMethodListener(name, self)
    end
    interfaces.each do |future|
      if future.isResolved
        iface = future.resolve
        if iface.kind_of?(MirrorType)
          MirrorType(iface).addMethodListener(name, self)
        end
      end
    end
  end

  def invalidateMethod(name:String)
    listeners = Set(@method_listeners[name])
    if listeners
      HashSet.new(listeners).each do |l: MethodListener|
        l.methodChanged(self, name)
      end
    end
  end

  def methodChanged(type, name)
    invalidateMethod(name)
  end

  def declareField(field:JVMMethod):void
    raise IllegalArgumentException, "Cannot add fields to #{self}"
  end

  def unmeta
    self
  end

  # Subclasses can override to add methods after construction.
  def load_methods:boolean
    true
  end

  def toString
    @name
  end

  def box:JVMType
    @boxed
  end

  attr_writer boxed: JVMType

  def unbox:JVMType
    @unboxed
  end

  attr_writer unboxed: JVMType

  def equals(other)
    other.kind_of?(MirrorType) && isSameType(MirrorType(other))
  end

  def hashCode:int
    hash = 23 + 37 * (getTypeArguments.hashCode)
    37 * hash + getAsmType.hashCode
  end

  def isSameType(other)
    import static org.mirah.util.Comparisons.*
    return true if areSame(self, other)
    return false if other.getKind != TypeKind.DECLARED
    return false unless other.kind_of?(DeclaredType) &&
                        getTypeArguments.equals(
                          DeclaredType(Object(other)).getTypeArguments)
    getAsmType().equals(other.getAsmType)
  end

  def directSupertypes
    @cached_supertypes ||= begin
      supertypes = LinkedList.new
      skip_super = JVMTypeUtils.isInterface(self) && interfaces.length > 0
      if skip_super
        # N/A
      elsif superclass
        supertypes.add superclass
      elsif @context
        object_type = MirrorType(
               @context[MirrorTypeSystem].loadNamedType(
                  "java.lang.Object").resolve)
        unless self.isSameType object_type
          supertypes.add(object_type)
        end
      end
      interfaces.each do |i|
        resolved = i.resolve
        # Skip error supertypes
        if resolved.kind_of?(MirrorType)
          supertypes.add(resolved)
        end
      end
      supertypes
    end
  end

  def isSupertypeOf(other)
    return true if getAsmType.equals(other.getAsmType)
    other.directSupertypes.any? {|x| isSupertypeOf(MirrorType(x))}
  end

  def getMembers(name:String)
    List(@members[name])
  end

  def getMethod(name:String, params:List):JVMMethod
    nil
  end

  def erasure
    self
  end
end

class AsyncMirror < BaseType

  def self.initialize:void
    @@log = Logger.getLogger(AsyncMirror.class.getName)
  end

  def initialize(context:Context, type:Type, flags:int, superclass:TypeFuture, interfaces:TypeFuture[])
    super(context, type, flags, nil)
    @watched_methods = HashSet.new
    setSupertypes(superclass, interfaces)
  end

  def initialize(context:Context, type:Type, flags:int)
    super(context, type, flags, nil)
    @watched_methods = HashSet.new
  end

  def setSupertypes(superclass:TypeFuture, interfaces:TypeFuture[]):void
    mirror = self
    @interfaces = interfaces
    if superclass
      superclass.onUpdate do |x, resolved|
        mirror.resolveSuperclass(JVMType(resolved))
      end
    end
    @interfaces.each do |i|
      i.onUpdate do |x, resolved|
        mirror.resolveSupertype(resolved)
      end
    end
  end

  def resolveSuperclass(resolved:JVMType):void
    @@log.finest "[#{self}] resolving super class #{resolved}"
    @superclass = resolved
    resolveSupertype(resolved)
  end

  def resolveSupertype(resolved:ResolvedType):void
    if resolved.kind_of?(MirrorType)
      parent = MirrorType(resolved)
      @watched_methods.each do |name:String|
        parent.addMethodListener(name, self)
      end
    end
    notifyOfIncompatibleChange
  end

  def addMethodListener(name, listener)
    @watched_methods.add(name)
    super
  end

  def superclass
    @superclass
  end

  def interfaces:TypeFuture[]
    @interfaces
  end
end