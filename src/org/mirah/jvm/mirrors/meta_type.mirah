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

import java.util.List

import org.objectweb.asm.Opcodes
import org.objectweb.asm.Type
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMMethod

# package_private
class MetaType < BaseType
  def initialize(type:MirrorType)
    super(nil, type.name, type.getAsmType, type.flags | Opcodes.ACC_STATIC,
          type.superclass)
    @unmeta = type
  end

  attr_reader unmeta: MirrorType

  def isMeta:boolean; true; end

  def widen(other)
    # What does this mean?
    unmeta.widen(other)
  end

  def notifyOfIncompatibleChange
    unmeta.notifyOfIncompatibleChange
  end

  def onIncompatibleChange(listener:Runnable)
    unmeta.onIncompatibleChange(listener)
  end

  def isFullyResolved():boolean
    unmeta.isFullyResolved()
  end

  def invalidateMethod(name)
    unmeta.invalidateMethod(name)
  end

  def addMethodListener(name, listener)
    unmeta.addMethodListener(name, listener)
  end

  def hasMember(name:String)
    unmeta.hasMember(name)
  end

  def getDeclaredField(name:String)
    field = unmeta.getDeclaredField(name)
    if field && Opcodes.ACC_STATIC == (Member(field).flags & Opcodes.ACC_STATIC)
      field
    else
      nil
    end
  end
end
