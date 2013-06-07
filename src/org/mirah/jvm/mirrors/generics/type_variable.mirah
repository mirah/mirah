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
import javax.lang.model.type.TypeVariable as TypeVariableModel
import org.mirah.jvm.mirrors.NullType

class TypeVariable implements TypeVariableModel
  @@lowerBound = NullType.new
  def initialize(name:String, ancestor:TypeMirror=nil)
    @name = name
    @extendsBound = ancestor
  end
  def getLowerBound
    @@lowerBound
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
end