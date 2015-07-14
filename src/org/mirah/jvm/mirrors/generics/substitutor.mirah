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

import java.util.LinkedList
import java.util.Map
import org.mirah.util.Logger
import javax.lang.model.type.TypeMirror
import javax.lang.model.util.SimpleTypeVisitor6
import org.mirah.util.Context
import org.mirah.jvm.mirrors.ArrayType
import org.mirah.jvm.mirrors.DeclaredMirrorType
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.jvm.model.IntersectionType
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.ResolvedType
import org.mirah.typer.TypeFuture

class CapturedWildcard < TypeVariable
  def initialize(context:Context, upper:MirrorType, lower:MirrorType)
    super(context, "?", upper)
    @lowerBound = lower
  end

  def getLowerBound
    @lowerBound
  end

  def toString
    if @lowerBound
      "[? extends #{getUpperBound}, super #{@lowerBound}]"
    else
      "[? extends #{getUpperBound}]"
    end
  end
end

class Substitutor < SimpleTypeVisitor6
  def initialize(context:Context, typeVars:Map)
    @context = context
    @types = context[MirrorTypeSystem]
    @typeVars = typeVars
    @substitutions = 0
    @type_parameters = LinkedList.new
  end

  def self.initialize:void
    @@log = Logger.getLogger(Substitutor.class.getName)
  end

  def defaultAction(e, p)
    popTypeParam
    future(e)
  end

  def popTypeParam
    if @type_parameters.isEmpty
      nil
    else
      TypeFuture(@type_parameters.removeFirst).resolve
    end
  end

  def visitArray(t, p)
    popTypeParam
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
    popTypeParam
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
    popTypeParam
    saved_substitutions = @substitutions
    saved_parameters = @type_parameters
    begin
      @type_parameters = LinkedList.new
      if t.kind_of?(MirrorType)
        erasure = DeclaredMirrorType(MirrorType(Object(t)).erasure)
        @type_parameters.addAll(erasure.getTypeVariableMap.values)
      end
      @@log.fine("Type parameters for #{t} = #{@type_parameters}")
      newArgs = t.getTypeArguments.map do |x:TypeMirror|
        visit(x, p)
      end
      if saved_substitutions == @substitutions
        future(t)
      else
        # If any type parameters were substituted, re-invoke the type
        @types.parameterize(future(MirrorType(Object(t)).erasure), newArgs)
      end
    ensure
      @type_parameters = saved_parameters
    end
  end

  def visitWildcard(t, p)
    # Apply capture conversion.
    param = TypeVariable(popTypeParam)
    upper = MirrorType(param.getUpperBound)
    lower = param.getLowerBound
    if t.getSuperBound
      lower = t.getSuperBound
    end
    if t.getExtendsBound && !upper.isSameType(MirrorType(t.getExtendsBound))
      lub = LubFinder.new(@context)
      upper = MirrorType(Object(lub.leastUpperBound([upper, t.getExtendsBound])))
    end
    @substitutions += 1
    future(CapturedWildcard.new(@context, upper, MirrorType(lower)))
  end

  def future(t:Object)
    BaseTypeFuture.new.resolved(ResolvedType(t))
  end
end