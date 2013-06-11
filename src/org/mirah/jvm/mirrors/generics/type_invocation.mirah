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

import java.util.List
import javax.lang.model.type.DeclaredType
import org.mirah.jvm.mirrors.MirrorProxy
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.typer.TypeFuture

class TypeInvocation < MirrorProxy implements DeclaredType
  def initialize(raw:MirrorType, superclass:MirrorType, interfaces:TypeFuture[], args:List)
    super(raw)
    @superclass = superclass
    @interfaces = interfaces
    @typeArguments = args
  end

  def superclass
    @superclass
  end

  def interfaces:TypeFuture[]
    @interfaces
  end

  def getTypeArguments
    @typeArguments
  end

  def toString
    sb = StringBuilder.new(target.toString)
    sb.append('<')
    first = true
    @typeArguments.each do |arg|
      if first
        first = false
      else
        sb.append(', ')
      end
      sb.append(arg)
    end
    sb.append('>')
    sb.toString
  end
end