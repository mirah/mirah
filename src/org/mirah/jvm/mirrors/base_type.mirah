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
import java.util.ArrayList
import java.util.LinkedList
import java.util.List
import java.util.Set

import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.Type
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMMethod
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.ErrorType
import org.mirah.typer.MethodType
import org.mirah.typer.ResolvedType
import org.mirah.typer.TypeFuture

interface MethodListener
  def methodChanged(klass:JVMType, name:String):void; end
end

# package_private
interface MirrorType < JVMType
  def notifyOfIncompatibleChange:void; end
  def onIncompatibleChange(listener:Runnable):void; end
  def getDeclaredMethods(name:String):List; end  # List<Member>
  def addMethodListener(name:String, listener:MethodListener):void; end
  def invalidateMethod(name:String):void; end
  def add(member:JVMMethod):void; end
  def unmeta:MirrorType; end
end

# package_private
class BaseType implements MirrorType

  def initialize(type:Type, flags:int, superclass:JVMType)
    initialize(type.getClassName, type, flags, superclass)
  end

  def initialize(name:String, type:Type, flags:int, superclass:JVMType)
    @name = name
    @type = type
    @flags = flags
    @superclass = superclass
    @members = {}
    @method_listeners = {}
    @compatibility_listeners = []
  end

  attr_reader superclass:JVMType, name:String, type:Type, flags:int

  def notifyOfIncompatibleChange:void
    @compatibility_listeners.each do |l|
      Runnable(l).run()
    end
    @method_listeners.keySet.each do |n|
      invalidateMethod(String(n))
    end
  end

  def onIncompatibleChange(listener:Runnable)
    @compatibility_listeners.add(listener)
  end

  def assignableFrom(other)
    MethodLookup.isSubType(other, self)
  end

  def widen(other)
    if assignableFrom(other)
      self
    elsif other.assignableFrom(self)
      other
    else
      ErrorType.new([["Incompatible types #{self} and #{other}."]])
    end
  end

  def isMeta:boolean; false; end
  def isBlock:boolean; false; end
  def isError:boolean; false; end
  def matchesAnything:boolean; false; end

  def internal_name:String; @type.getInternalName; end
  def class_id:String; @type.getDescriptor; end
  def getAsmType:Type; @type; end

  def isPrimitive:boolean
    sort = @type.getSort
    sort != Type.OBJECT && sort != Type.ARRAY
  end

  def isEnum:boolean
    0 != (@flags & Opcodes.ACC_ENUM)
  end
  def isInterface:boolean
    0 != (@flags & Opcodes.ACC_INTERFACE)
  end
  def isAnnotation:boolean
    0 != (@flags & Opcodes.ACC_ANNOTATION)
  end
  def retention:String; nil; end

  def isArray:boolean
    @type.getSort == Type.ARRAY
  end
  def getComponentType:JVMType; nil; end

  def hasStaticField(name:String):boolean
    field = getDeclaredField(name)
    field && field.kind.name.startsWith("STATIC_")
  end

  # This should only used by StringCompiler to lookup
  # StringBuilder.append(). This really should happen
  # during type inference :-(
  def getMethod(name:String, params:List):JVMMethod
    @methods_loaded ||= load_methods
    members = List(@members[name])
    if members
      members.each do |m|
        member = Member(m)
        if member.argumentTypes.equals(params)
          return member
        end
      end
    end
    t = MethodLookup.findMethod(nil, self, name, params, nil, nil).resolve
    ResolvedCall(MethodType(t).returnType).member
  end

  def getDeclaredMethods(name:String)
    @methods_loaded ||= load_methods
    # TODO: should this filter out fields?
    List(@members[name]) || Collections.emptyList
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
    listeners = List(@method_listeners[name] ||= LinkedList.new)
    listeners.add(listener)
  end

  def invalidateMethod(name:String)
    listeners = List(@method_listeners[name])
    if listeners
      listeners.each do |l|
        MethodListener(l).methodChanged(self, name)
      end
    end
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
end
