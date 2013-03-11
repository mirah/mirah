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
import java.util.LinkedList
import java.util.List
import java.util.logging.Logger

import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.Type

import mirah.lang.ast.Position

import org.mirah.typer.AssignableTypeFuture
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.DelegateFuture
import org.mirah.typer.ErrorType
import org.mirah.typer.MethodFuture
import org.mirah.typer.ResolvedType
import org.mirah.typer.TypeFuture
import org.mirah.typer.TypeSystem

import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.MemberKind

class MirrorTypeSystem implements TypeSystem
  def initialize(classloader:ClassLoader = MirrorTypeSystem.class.getClassLoader)
    @loader = SimpleAsyncMirrorLoader.new(AsyncLoaderAdapter.new(
        BytecodeMirrorLoader.new(classloader, PrimitiveLoader.new)))
    @object_future = wrap(Type.getType('Ljava/lang/Object;'))
    @object = BaseType(@object_future.resolve)
    @main_type = wrap(Type.getType('LFooBar;'))
    @primitives = {
      boolean: 'Z',
      byte: 'B',
      char: 'C',
      short: 'S',
      int: 'I',
      long: 'J',
      float: 'F',
      double: 'D',
      void: 'V',
    }
  end

  def self.initialize:void
    @@log = Logger.getLogger(MirrorTypeSystem.class.getName)
  end

  def getSuperClass(type)
    future = BaseTypeFuture.new
    if type.kind_of?(BaseTypeFuture)
      future.position = BaseTypeFuture(type).position 
    end
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
    createMember(
        BaseType(target.resolve), name, argTypes, declaredReturnType,
        position)
  end

  def getMethodType(call)
    future = DelegateFuture.new()
    if call.resolved_parameters.all?
      target = MirrorType(call.resolved_target)
      future.type = MethodLookup.findMethod(
          call.scope, target, call.name,
          call.resolved_parameters, call.position)
      target.addMethodListener(call.name) do |klass, name|
        if klass == target
          future.type = MethodLookup.findMethod(
              call.scope, target, call.name,
              call.resolved_parameters, call.position)
        end
      end
    end
    future
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
    @loader.defineMirror(type, future)
    superclass ||= @object_future
    isDefined = false
    superclass.onUpdate do |x, resolved|
      unless isDefined
        jvm_superclass = resolved.isError ? object_type : JVMType(resolved)
        future.resolved(BaseType.new(type, Opcodes.ACC_PUBLIC, jvm_superclass))
      end
    end
    future
  end

  def get(scope, typeref)
    desc = @primitives[typeref.name]
    type = if desc
      Type.getType(String(desc))
    else
      Type.getObjectType(typeref.name)
    end
    @loader.loadMirrorAsync(type)
  end

  def wrap(type:Type):TypeFuture
    future = @loader.loadMirrorAsync(type)
    if (!future.isResolved) || future.resolve.isError
      jvmtype = BaseType.new(type, Opcodes.ACC_PUBLIC, @object)
      @loader.defineMirror(type, BaseTypeFuture.new.resolved(jvmtype))
    end
    future
  end

  def createMember(target:BaseType, name:String, arguments:List,
                   returnType:TypeFuture, position:Position):MethodFuture
    returnFuture = AssignableTypeFuture.new(position)

    flags = Opcodes.ACC_PUBLIC
    kind = MemberKind.METHOD
    if target.isMeta
      target = BaseType(MetaType(target).unmeta)
      flags |= Opcodes.ACC_STATIC
      kind = MemberKind.STATIC_METHOD
    end
    member = AsyncMember.new(flags, target, name, arguments, returnFuture, kind)

    returnFuture.error_message =
        "Cannot determine return type for method #{member}"
    returnFuture.declare(returnType, position) if returnType
    
    target.add(member)

    MethodFuture.new(name, member.argumentTypes, returnFuture, false, position)
  end
end

class FakeMember < Member
  def self.create(types:MirrorTypeSystem, description:String, flags:int=-1)
    m = /^(@)?([^.]+)\.(.+)$/.matcher(description)
    unless m.matches
      raise IllegalArgumentException, "Invalid method specification #{description}"
    end
    abstract = !m.group(1).nil?
    klass = wrap(types, Type.getType(m.group(2)))
    method = Type.getType(m.group(3))
    returnType = wrap(types, method.getReturnType)
    args = LinkedList.new
    method.getArgumentTypes.each do |arg|
      args.add(wrap(types, arg))
    end
    flags = Opcodes.ACC_PUBLIC if flags == -1
    flags |= Opcodes.ACC_ABSTRACT if abstract
    FakeMember.new(description, flags, klass, returnType, args)
  end

  def self.wrap(types:MirrorTypeSystem, type:Type)
    JVMType(types.wrap(type).resolve)
  end

  def initialize(description:String, flags:int,
                 klass:JVMType, returnType:JVMType, args:List)
    super(flags, klass, 'foobar', args, returnType, MemberKind.METHOD)
    @description = description
  end

  def toString
    @description
  end
end