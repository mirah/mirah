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

import org.mirah.util.Logger
import java.util.Collections
import java.util.HashMap
import java.util.List
import java.util.LinkedList
import java.util.Map
import javax.lang.model.type.DeclaredType
import javax.lang.model.type.TypeKind
import org.mirah.jvm.mirrors.AsyncMirror
import org.mirah.jvm.mirrors.JvmErrorType
import org.mirah.jvm.mirrors.MirrorProxy
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.jvm.mirrors.DeclaredMirrorType
import org.mirah.jvm.types.JVMTypeUtils
import org.mirah.typer.TypeFuture
import org.mirah.typer.ErrorType
import org.mirah.util.Context

class TypeInvocation < AsyncMirror implements DeclaredMirrorType
  def initialize(context:Context, raw:MirrorType, superclass:TypeFuture, interfaces:TypeFuture[], args:List, typeVariableMap:Map)
    super(context, raw.getAsmType, raw.flags, superclass, interfaces)
    @context = context
    @raw = raw
    @interfaces = interfaces
    @typeArguments = args
    mirror = self
    @typeArguments.each do |a:TypeFuture|
      a.onUpdate do |x, resolved|
        mirror.notifyOfIncompatibleChange
      end
    end
    @typeVariableMap = Collections.unmodifiableMap(HashMap.new(typeVariableMap))
  end

  def self.initialize:void
    @@log = Logger.getLogger(TypeInvocation.class.getName)
  end

  def signature
    DeclaredMirrorType(@raw).signature
  end

  def interfaces:TypeFuture[]
    @interfaces
  end

  def getTypeArguments
    return [] if @typeArguments.nil?
    @typeArguments.map do |a:TypeFuture|
      resolved = a.resolve
      if resolved.kind_of?(ErrorType)
        JvmErrorType.new(@context, ErrorType(resolved))
      else
        MirrorType(resolved)
      end
    end
  end

  def getTypeVariableMap
    @typeVariableMap
  end

  def toString

    sb = StringBuilder.new
    sb.append @raw
    sb.append('<')
    first = true
    getTypeArguments.each do |arg|
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

  def equals(other)
    import static org.mirah.util.Comparisons.*
    return true if areSame(self, other)
    other.kind_of?(MirrorType) && isSameType(MirrorType(other))
  end

  def hashCode:int
    hash = 23 + 37 * (getTypeArguments.hashCode)
    37 * hash + getAsmType.hashCode
  end

  def isSameType(other)
    return false if other.getKind != TypeKind.DECLARED
    getTypeArguments.zip(DeclaredType(Object(other)).getTypeArguments) do
      |a:MirrorType, b:MirrorType|
      return false if b.nil?
      return false unless a.isSameType(b)
    end
    getAsmType().equals(other.getAsmType)
  end

  def isSupertypeOf(other)
    if getAsmType.equals(other.getAsmType) && other.getKind == TypeKind.DECLARED
      other_args = DeclaredType(Object(other)).getTypeArguments
      if other_args.nil? || other_args.isEmpty
        # Allow unchecked conversion
        return true
      end
      match = true
      getTypeArguments.zip(other_args) do |a:MirrorType, b:MirrorType|
        unless b && a.isSupertypeOf(b)
          match = false
          break
        end
      end
      return match
    end
    other.directSupertypes.any? {|x:MirrorType| isSupertypeOf(x)}
  end

  def directSupertypes
    types = LinkedList.new(super)
    types.addFirst(@raw)
    types
  end

  def erasure
    @raw
  end
end