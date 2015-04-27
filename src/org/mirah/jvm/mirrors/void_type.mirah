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

import mirah.objectweb.asm.Opcodes
import mirah.objectweb.asm.Type
import org.mirah.jvm.types.MemberKind
import org.mirah.typer.ErrorType
import javax.lang.model.type.NoType
import javax.lang.model.type.TypeKind

class VoidType < BaseType implements NoType
  def initialize
    super(nil, Type.getType("V"), Opcodes.ACC_PUBLIC, nil)
  end

  def getKind
    TypeKind.VOID
  end

  def accept(v, p)
    v.visitNoType(self, p)
  end

  def isSameType(other)
    TypeKind.VOID == other.getKind
  end

  def hashCode
    TypeKind.VOID.hashCode
  end

  def directSupertypes
    []
  end

  def widen(other)
    ErrorType.new([["Incompatible types #{self}, #{other}"]])
  end

end
