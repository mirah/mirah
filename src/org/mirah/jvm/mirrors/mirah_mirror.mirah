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

import org.jruby.org.objectweb.asm.Type
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.JVMType
import org.mirah.typer.TypeFuture


# Mirror for a type being loaded from a .mirah file.
class MirahMirror < BaseType
  def initialize(type:Type, flags:int, superclass:TypeFuture, interfaces:TypeFuture[])
    super(type, flags, nil)
    mirror = self
    @interfaces = interfaces
    superclass.onUpdate do |x, resolved|
      mirror.resolveSuperclass(JVMType(resolved))
    end
    @interfaces.each do |i|
      i.onUpdate do |x, resolved|
        mirror.notifyOfIncompatibleChange
      end
    end
    @fields = {}
  end

  def resolveSuperclass(resolved:JVMType)
    @superclass = resolved
    notifyOfIncompatibleChange
  end

  def superclass
    @superclass
  end

  def interfaces:TypeFuture[]
    @interfaces
  end

  def declareField(field:JVMMethod)
    @fields[field.name] = field
  end

  def getDeclaredFields:JVMMethod[]
    fields = JVMMethod[@fields.size]
    @fields.values.toArray(fields)
    fields
  end
  def getDeclaredField(name:String):JVMMethod
    JVMMethod(@fields[name])
  end
end