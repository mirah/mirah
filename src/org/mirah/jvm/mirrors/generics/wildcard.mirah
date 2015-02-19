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
import javax.lang.model.type.WildcardType
import org.objectweb.asm.Opcodes
import org.mirah.jvm.mirrors.BaseType
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.util.Context

class Wildcard < BaseType implements WildcardType
  def initialize(context:Context, object:MirrorType, extendsBound:TypeMirror=nil, superBound:TypeMirror=nil)
    super(context, nil, nil, Opcodes.ACC_PUBLIC, nil)
    raise IllegalArgumentException unless (extendsBound.nil? || superBound.nil?)
    @object = object
    @extendsBound = extendsBound
    @superBound = superBound
  end

  def getExtendsBound
    if @extendsBound && MirrorType(@extendsBound).isSameType(@object)
      nil
    else
      @extendsBound
    end
  end

  def getSuperBound
    @superBound
  end
  
  def getKind
    TypeKind.WILDCARD
  end

  def equals(other)
    import static org.mirah.util.Comparisons.*
    areSame(other, self)
  end

  def hashCode
    System.identityHashCode(self)
  end

  def isSameType(other)
    other == self
  end

  def directSupertypes
    if @extendsBound
      [@extendsBound]
    else
      [@object]
    end
  end

  def isSupertypeOf(other)
    return false if @superBound.nil?
    MirrorType(@superBound).isSupertypeOf(other)
  end

  def accept(v, p)
    v.visitWildcard(self, p)
  end

  def erasure
    if @extendsBound
      MirrorType(@extendsBound).erasure
    else
      @object
    end
  end

  def getAsmType
    MirrorType(erasure).getAsmType
  end

  def toString
    if getExtendsBound
      "? extends #{@extendsBound}"
    elsif
      @superBound
      "? super #{@superBound}"
    else
      "?"
    end
  end
end