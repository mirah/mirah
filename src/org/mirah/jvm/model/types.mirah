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
import java.util.EnumMap
import javax.lang.model.type.NoType
import javax.lang.model.type.NullType
import javax.lang.model.type.PrimitiveType
import javax.lang.model.type.TypeVariable as TypeVariableModel
import javax.lang.model.type.TypeKind
import javax.lang.model.type.WildcardType
import javax.lang.model.util.Types as TypesModel
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.jvm.mirrors.MirrorTypeSystem

class Types implements TypesModel
  def initialize(types:MirrorTypeSystem)
    @types = types
    @primitives = EnumMap.new(
      TypeKind.BOOLEAN => types.loadNamedType('boolean').resolve,
      TypeKind.BYTE => types.loadNamedType('byte').resolve,
      TypeKind.CHAR => types.loadNamedType('char').resolve,
      TypeKind.DOUBLE => types.loadNamedType('double').resolve,
      TypeKind.FLOAT => types.loadNamedType('float').resolve,
      TypeKind.INT => types.loadNamedType('int').resolve,
      TypeKind.LONG => types.loadNamedType('long').resolve,
      TypeKind.SHORT => types.loadNamedType('short').resolve
    )
  end

  def boxedClass(p)
    TypeElement.new(MirrorType(MirrorType(p).box))
  end

  def getArrayType(component)
    ArrayType.new(component)
  end

  def getNoType(kind)
    if kind == TypeKind.VOID
      return NoType(@types.getVoidType.resolve)
    end
  end

  def getNullType
    NullType(@types.getNullType.resolve)
  end

  def getPrimitiveType(kind)
    PrimitiveType(@primitives[kind])
  end

  def directSupertypes(t)
    supertypes = ArrayList.new
    if t.kind_of?(MirrorType)
      m = MirrorType(t)
      unless m.isPrimitive || m.isInterface
        parent = m.superclass
        supertypes.add(parent) if parent
      end
      m.interfaces.each do |i|
        supertypes.add(i.resolve)
      end
    elsif t.getKind == TypeKind.WILDCARD
      w = WildcardType(t)
      if w.getExtendsBound
        supertypes.add(w.getExtendsBound)
      end
    elsif t.getKind == TypeKind.TYPEVAR
      supertypes.add(TypeVariableModel(t).getUpperBound)
    end
    supertypes
  end

  def asElement(t)
    TypeElement.new(MirrorType(t))
  end
end