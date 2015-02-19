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

package org.mirah.jvm.mirrors.generics

import javax.lang.model.type.TypeKind
import javax.lang.model.type.TypeMirror
import javax.lang.model.util.Types
import javax.lang.model.type.TypeVariable as TypeVariableModel
import org.objectweb.asm.Opcodes
import org.mirah.jvm.mirrors.BaseType
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.jvm.mirrors.NullType
import org.mirah.util.Context

# A declared type parameter.
class TypeVariable < BaseType implements TypeVariableModel
  def initialize(context:Context, name:String, ancestor:MirrorType)
    super(context, name, nil, Opcodes.ACC_PUBLIC, ancestor)
    @name = name
    raise IllegalArgumentException if ancestor.nil?
    @extendsBound = ancestor
    @lowerBound = context[Types].getNullType
  end
  def getAsmType
    @extendsBound.getAsmType
  end
  def getLowerBound
    @lowerBound
  end
  def getUpperBound
    @extendsBound
  end
  def toString
    @name
  end
  def getKind
    TypeKind.TYPEVAR
  end
  def accept(v, p)
    v.visitTypeVariable(self, p)
  end
  def isSameType(other)
    other == self
  end
  def isSupertypeOf(other)
    @extendsBound.isSupertypeOf(other)
  end
  def erasure
    @extendsBound.erasure
  end
  def equals(other)
    import static org.mirah.util.Comparisons.*
    areSame(other, self)
  end
  def hashCode
    System.identityHashCode(self)
  end
end