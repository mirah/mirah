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

import java.util.HashSet
import java.util.Set

import javax.lang.model.type.TypeMirror

class Constraints
  def initialize
    @super_constraints = HashSet.new
    @extends_constraints = HashSet.new
    @equal_constraints = HashSet.new
  end
  
  def addSuper(type:TypeMirror):void
    @super_constraints.add(type)
  end

  def getSuper:Set
    @super_constraints
  end

  def addExtends(type:TypeMirror):void
    @extends_constraints.add(type)
  end
  
  def getExtends:Set
    @extends_constraints
  end

  def addEqual(type:TypeMirror):void
    @equal_constraints.add(type)
  end

  def getEqual:Set
    @equal_constraints
  end

  def size
    @super_constraints.size + @extends_constraints.size + @equal_constraints.size
  end

  def toString
    sb = StringBuilder.new
    sb.append("<")
    unless @super_constraints.isEmpty
      sb.append("super: ")
      sb.append(@super_constraints)
      sb.append(" ")
    end
    unless @extends_constraints.isEmpty
      sb.append("extends: ")
      sb.append(@extends_constraints)
      sb.append(" ")
    end
    unless @equal_constraints.isEmpty
      sb.append("equal: ")
      sb.append(@equal_constraints)
      sb.append(" ")
    end
    sb.append(">")
    sb.toString
  end
end
