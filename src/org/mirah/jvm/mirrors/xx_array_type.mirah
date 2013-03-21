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

import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.Type
import org.mirah.jvm.types.MemberKind
import org.mirah.typer.TypeFuture
import org.mirah.typer.ResolvedType

class ArrayType < BaseType
  def initialize(component:MirrorType,
                 superclass:MirrorType,
                 loader:AsyncMirrorLoader)
    super(Type.getType("[#{component.class_id}"),
          Opcodes.ACC_PUBLIC,
          superclass)
    @interfaces = TypeFuture[2]
    @interfaces[0] =
         loader.loadMirrorAsync(Type.getType('Ljava/lang/Cloneable;'))
    @interfaces[1] =
         loader.loadMirrorAsync(Type.getType('Ljava/io/Serializable;'))
    @loader = loader
    @componentType = component
  end

  def interfaces:TypeFuture[]
    @interfaces
  end

  def add_method(name:String,
                 args:List,
                 returnType:ResolvedType,
                 kind:MemberKind):void
    add(Member.new(
        Opcodes.ACC_PUBLIC, self, name, args, MirrorType(returnType), kind))
  end

  def load_methods
    int_type = @loader.loadMirrorAsync(Type.getType('I')).resolve
    add_method("length", [], int_type, MemberKind.ARRAY_LENGTH)
    add_method("[]", [int_type], @componentType, MemberKind.ARRAY_ACCESS)
    add_method("[]=", [int_type, @componentType],
                @componentType, MemberKind.ARRAY_ASSIGN)
    true
  end
  
  def getComponentType
    @componentType
  end
end