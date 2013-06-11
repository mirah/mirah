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

class Wildcard implements WildcardType
  def initialize(extendsBound:TypeMirror=nil, superBound:TypeMirror=nil)
    raise IllegalArgumentException unless (extendsBound.nil? || superBound.nil?)
    @extendsBound = extendsBound
    @superBound = superBound
  end

  def getExtendsBound
    @extendsBound
  end

  def getSuperBound
    @superBound
  end
  
  def getKind
    TypeKind.WILDCARD
  end

  def accept(v, p)
    v.visitWildcard(self, p)
  end
  
  def toString
    if @extendsBound
      "? extends #{@extendsBound}"
    elsif
      @superBound
      "? super #{@superBound}"
    else
      "?"
    end
  end
end