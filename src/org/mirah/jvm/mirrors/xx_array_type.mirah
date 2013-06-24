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

package org.mirah.jvm.mirrors

import java.util.List
import java.util.logging.Logger

import javax.lang.model.type.ArrayType as ArrayModel
import javax.lang.model.type.TypeKind
import javax.lang.model.type.TypeMirror
import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.Type
import org.mirah.builtins.ArrayExtensions
import org.mirah.builtins.EnumerableExtensions
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMTypeUtils
import org.mirah.jvm.types.MemberKind
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.TypeFuture
import org.mirah.typer.ResolvedType

class ArrayType < BaseType implements ArrayModel
  def self.initialize:void
    @@log = Logger.getLogger(ArrayType.class.getName)
  end

  def self.getSupertype(component:MirrorType)
    use_object = JVMTypeUtils.isPrimitive(component)
    if "Ljava/lang/Object;".equals(component.getAsmType.getDescriptor)
      use_object = true 
    end
    if use_object || component.superclass.nil?
      Type.getType("Ljava/lang/Object;")
    else
      Type.getType("[#{component.superclass.getAsmType.getDescriptor}")
    end
  end

  def initialize(component:MirrorType, loader:AsyncMirrorLoader)
    super(Type.getType("[#{component.getAsmType.getDescriptor}"),
          Opcodes.ACC_PUBLIC, nil)
    @loader = loader
    @int_type = loader.loadMirrorAsync(Type.getType('I')).resolve
    @componentType = component
    sync_loader = SyncLoaderAdapter.new(loader)
    BytecodeMirrorLoader.extendClass(self, ArrayExtensions.class, sync_loader)
    BytecodeMirrorLoader.extendClass(self, EnumerableExtensions.class, sync_loader)
  end

  def initialize(component:MirrorType, loader:MirrorLoader)
    super(Type.getType("[#{component.getAsmType.getDescriptor}"),
          Opcodes.ACC_PUBLIC, nil)
    @loader = AsyncLoaderAdapter.new(loader)
    @int_type = loader.loadMirror(Type.getType('I'))
    @componentType = component
    BytecodeMirrorLoader.extendClass(self, ArrayExtensions.class, loader)
    BytecodeMirrorLoader.extendClass(self, EnumerableExtensions.class, loader)
  end

  def interfaces:TypeFuture[]
    if JVMTypeUtils.isPrimitive(@componentType) ||
        "Ljava/lang/Object;".equals(@componentType.getAsmType.getDescriptor)
      interfaces = TypeFuture[3]
      interfaces[0] = @loader.loadMirrorAsync(
          Type.getType('Ljava/lang/Object;'))
      interfaces[1] = @loader.loadMirrorAsync(
          Type.getType('Ljava/lang/Cloneable;'))
      interfaces[2] = @loader.loadMirrorAsync(
          Type.getType('Ljava/io/Serializable;'))
      interfaces
    else
      supertypes = @componentType.directSupertypes
      interfaces = TypeFuture[supertypes.size]
      supertypes.map do |x|
         BaseTypeFuture.new.resolved(ArrayType.new(MirrorType(x), @loader))
      end.toArray(interfaces)
      interfaces
    end
  end

  def add_method(name:String,
                 args:List,
                 returnType:ResolvedType,
                 kind:MemberKind):void
    add(Member.new(
        Opcodes.ACC_PUBLIC, self, name, args, MirrorType(returnType), kind))
  end

  def load_methods
    add_method("length", [], @int_type, MemberKind.ARRAY_LENGTH)
    add_method("[]", [@int_type], @componentType, MemberKind.ARRAY_ACCESS)
    add_method("[]=", [@int_type, @componentType],
                @componentType, MemberKind.ARRAY_ASSIGN)
    true
  end
  
  def getComponentType:MirrorType
    @componentType
  end
  # FIXME: Manual bridge methods
  def getComponentType:TypeMirror
    @componentType
  end
  def getComponentType:JVMType
    @componentType
  end

  def getKind; TypeKind.ARRAY; end
  def accept(v, p); v.visitArray(self, p); end

  def hashCode
    @componentType.hashCode
  end

  def isSameType(other)
    result = if other.getKind == TypeKind.ARRAY
      @componentType.isSameType(MirrorType(ArrayModel(other).getComponentType))
    else
      false
    end
    @@log.finer("#{self} #{result ? '=' : '!='} #{other}")
    result
  end

  def isSupertypeOf(other)
    result = if JVMTypeUtils.isPrimitive(@componentType)
      isSameType(other)
    elsif other.getKind != TypeKind.ARRAY
      false
    else
      super
    end
    @@log.finer("#{self} #{result ? '>' : '!>'} #{other}")
    result
  end

  def toString
    "#{@componentType}[]"
  end
end