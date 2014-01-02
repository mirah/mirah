# Copyright (c) 2012 The Mirah project authors. All Rights Reserved.
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

package org.mirah.jvm.model

import java.util.ArrayList
import java.util.Collections
import java.util.List
import javax.lang.model.type.DeclaredType
import javax.lang.model.type.TypeKind
import javax.lang.model.type.TypeMirror
import org.mirah.jvm.mirrors.BaseType
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.util.Context

class IntersectionType < BaseType implements DeclaredType
  def initialize(context:Context, types:List)
    super(context, nil, nil, 0, nil)
    @types = ArrayList.new(types)
    Collections.sort(@types) do |a, b|
      # Move the interfaces after the superclass
      a_is_class = a.kind_of?(MirrorType) && !MirrorType(a).isInterface
      b_is_class = b.kind_of?(MirrorType) && !MirrorType(b).isInterface
      if a_is_class && b_is_class
        raise IllegalArgumentException, "Multiple superclasses in #{types}"
      elsif a_is_class
        -1
      else
        if b_is_class
          1
        else
          0
        end
      end
    end
  end

  def getAsmType
    MirrorType(erasure).getAsmType
  end

  def directSupertypes
    @types
  end

  def erasure
    TypeMirror(@types.get(0))
  end

  def getKind
    TypeKind.DECLARED
  end

  def accept(v, p)
    v.visitDeclared(self, p)
  end

  def equals(other)
    other.kind_of?(IntersectionType) &&
        @types.equals(IntersectionType(other).directSupertypes)
  end

  def isSameType(other)
    equals(other)
  end

  def isSupertypeOf(other)
    @types.any? {|t:MirrorType| t.isSupertypeOf(other)}
  end

  def hashCode
    @types.hashCode
  end

  def getTypeArguments
    Collections.emptyList
  end

  def name
    toString
  end

  def toString
    sb = StringBuilder.new
    first = true
    @types.each do |x|
      if first
        first = false
      else
        sb.append " & "
      end
      sb.append(x)
    end
    sb.toString
  end
end