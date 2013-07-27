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
import javax.lang.model.util.SimpleTypeVisitor6
import org.mirah.util.Context
import org.mirah.jvm.mirrors.ArrayType
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.ResolvedType
import org.mirah.typer.TypeFuture

class Substitutor < SimpleTypeVisitor6
  def initialize(context:Context, typeVars:Map)
    @context = context
    @types = context[MirrorTypeSystem]
    @typeVars = typeVars
    @substitutions = 0
  end
  def defaultAction(e, p)
    future(e)
  end

  def visitArray(t, p)
    c = t.getComponentType
    saved = @substitutions
    c2 = TypeFuture(visit(c, p))
    array = if saved == @substitutions
      t
    else
      ArrayType.new(@context, MirrorType(c2.resolve))
    end
    future(array)
  end

  def visitTypeVariable(t, p)
    t2 = @typeVars[t.toString]
    # What if the bounds involve typevars?
    if t2
      @substitutions += 1
      t2
    else
      future(t)
    end
  end

  def visitDeclared(t, p)
    saved = @substitutions
    newArgs = t.getTypeArguments.map do |x:TypeMirror|
      visit(x, p)
    end
    if saved == @substitutions
      future(t)
    else
      # If any type parameters were substituted, re-invoke the type
      @types.parameterize(future(MirrorType(t).erasure), newArgs)
    end
  end

  def future(t:Object)
    BaseTypeFuture.new.resolved(ResolvedType(t))
  end
end