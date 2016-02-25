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
import org.objectweb.asm.Opcodes
import org.objectweb.asm.Type
import org.mirah.jvm.types.JVMField
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.MemberKind
import org.mirah.typer.TypeFuture
import org.mirah.util.Context


# Mirror for a type being loaded from a .mirah file.
class MirahMirror < AsyncMirror
  attr_accessor flags:int

  def initialize(context:Context, type:Type, flags:int, superclass:TypeFuture, interfaces:TypeFuture[])
    super
    @flags = flags
    @default_constructor = Member.new(Opcodes.ACC_PUBLIC, self, '<init>', [], self, MemberKind.CONSTRUCTOR)
    @fields = {}
  end

  def getTypeVariableMap
    Collections.emptyMap
  end

  def declareField(field:JVMField)
    @fields[field.name] = field
  end

  def getDeclaredFields:JVMField[]
    fields = JVMField[@fields.size]
    @fields.values.toArray(fields)
    fields
  end
  def getDeclaredField(name:String):JVMField
    JVMField(@fields[name])
  end

  def getDeclaredMethods(name)
    result = super
    if result.isEmpty && "<init>".equals(name)
      [@default_constructor]
    else
      result
    end
  end
end