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
import org.jruby.org.objectweb.asm.Type
import org.jruby.org.objectweb.asm.tree.ClassNode
import org.jruby.org.objectweb.asm.tree.FieldNode
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.MemberKind
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.TypeFuture
import mirah.lang.ast.TypeRefImpl


interface MirrorLoader
  def loadMirror(type:Type):MirrorType; end
end

interface AsyncMirrorLoader
  # The future must resolve to a MirrorType.
  def loadMirrorAsync(type:Type):TypeFuture; end
end

class BytecodeMirror < BaseType
  def initialize(klass:ClassNode, loader:MirrorLoader)
    super(Type.getObjectType(klass.name), klass.access, BytecodeMirror.lookupType(loader, klass.superName))
    @loader = loader
    @fields = klass.fields
    @interfaces = TypeFuture[klass.interfaces.size]
    it = klass.interfaces.iterator
    @interfaces.length.times do |i|
      @interfaces[i] = BaseTypeFuture.new.resolved(lookupType(String(it.next)))
    end
  end
  
  def self.lookupType(loader:MirrorLoader, internalName:String)
    if internalName
      return loader.loadMirror(Type.getType("L#{internalName};"))
    end
    nil
  end
  
  def lookupType(internalName:String):MirrorType
    return BytecodeMirror.lookupType(@loader, internalName)
  end
  def lookup(type:Type):MirrorType
    @loader.loadMirror(type)
  end
  
  def interfaces:TypeFuture[]
    @interfaces
  end

  def getDeclaredFields:JVMMethod[]
    @field_mirrors ||= begin
      mirrors = JVMMethod[@fields.size]
      it = @fields.iterator
      @fields.size.times do |i|
        field = FieldNode(it.next)
        type = lookup(Type.getType(field.desc))
        mirrors[i] = Member.new(field.access, self, field.name, [], type, MemberKind.FIELD_ACCESS)
      end
      @fields = nil
      mirrors
    end
  end
  
  def getDeclaredField(name:String)
    @field_mirrors.each do |field|
      if field.name.equals(name)
        return field
      end
    end
    nil
  end
end
