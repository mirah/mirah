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

package org.mirah.jvm.mirrors.generics

import java.util.Map
import javax.lang.model.type.TypeMirror
import javax.lang.model.util.Types
import javax.lang.model.util.SimpleTypeVisitor6
import org.mirah.util.Context

class Substitutor < SimpleTypeVisitor6
  def initialize(context:Context, typeVars:Map)
    @types = context[Types]
    @typeVars = typeVars
  end
  def defaultAction(e, p)
    e
  end

  def visitArray(t, p)
    c = t.getComponentType
    c2 = TypeMirror(visit(c, p))
    if c == c2
      t
    else
      @types.getArrayType(c2)
    end
  end

  def visitTypeVariable(t, p)
    t2 = @typeVars[t.toString]
    # What if the bounds involve typevars?
    t2 || t
  end

  def visitDeclared(t, p)
    newArgs = t.getTypeArguments.map do |x:TypeMirror|
      visit(x, p)
    end
    t.getTypeArguments.zip(newArgs) do |a, b|
      if a != b
        # If any type parameters were substituted, re-invoke the type
        elem = TypeElement(@types.asElement(t))
        args = TypeMirror[newArgs.size]
        newArgs.toArray(args)
        return @types.getDeclaredType(elem, args)
      end
    end
    t
  end
end