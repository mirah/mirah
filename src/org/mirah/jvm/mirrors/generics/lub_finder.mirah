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
import java.util.Map
import java.util.Collections
import java.util.HashMap
import java.util.LinkedHashMap
import java.util.LinkedList
import java.util.List
import java.util.Collection
import java.util.Set
import org.mirah.util.Logger
import javax.lang.model.element.TypeElement
import javax.lang.model.type.ArrayType
import javax.lang.model.type.DeclaredType
import javax.lang.model.type.TypeKind
import javax.lang.model.type.TypeMirror
import javax.lang.model.type.TypeVisitor
import javax.lang.model.type.WildcardType
import javax.lang.model.util.AbstractTypeVisitor6
import javax.lang.model.util.SimpleTypeVisitor6
import javax.lang.model.util.Types
import org.mirah.util.Context

import org.mirah.jvm.mirrors.MirrorType
import org.mirah.jvm.mirrors.MirrorProxy
import org.mirah.jvm.model.Cycle
import org.mirah.jvm.model.IntersectionType

# This class is not threadsafe
class LubFinder
  def initialize(context:Context)
    @context = context
    @types = context[Types]
    @cycles = HashMap.new
  end

  def self.initialize:void
    @@log = Logger.getLogger(LubFinder.class.getName)
  end

  def leastUpperBound(types:Collection):DeclaredType
    if @cycles.containsKey(types)
      DeclaredType(@cycles[types])
    else
      cycle_guard = @cycles[types] = Cycle.new
      ecs = erasedCandidateSet(types)
      @@log.finer("EC(#{types}) = #{ecs}")
      minimizeErasedCandidates(ecs.keySet)
      @@log.finer("MEC = #{ecs.keySet}")
      supertypes = List(ecs.values.map {|x:Set| candidateInvocation(x)})
      @@log.fine("lub candidates(#{types}) = #{supertypes}")
      result = if supertypes.size == 1
        DeclaredType(supertypes[0])
      elsif supertypes.size == 0
        nil
      else
        IntersectionType.new(@context, supertypes)
      end
      @cycles.remove(types)
      cycle_guard.target = MirrorType(Object(result))
      result
    end
  end

  # private
  def erasedSupertypes(t:TypeMirror):Map
    supertypes = LinkedHashMap.new
    processed = HashSet.new
    to_process = LinkedList.new
    to_process.add(t)
    until to_process.isEmpty
      type = unwrap(TypeMirror(to_process.removeFirst))
      next if processed.contains(type)
      erased = unwrap(@types.erasure(type))
      @@log.finest("Processing #{type}")
      processed.add(type)
      processed.add(erased)
      instantiations = Set(supertypes[erased])
      if instantiations.nil?
        instantiations = supertypes[erased] = HashSet.new
      end
      if instantiations.add(type)
        to_process.addAll(@types.directSupertypes(type))
      end
    end
    supertypes
  end

  def unwrap(t:TypeMirror):TypeMirror
    while t.kind_of?(MirrorProxy)
      t = MirrorProxy(t).target
    end
    t
  end

  def combineCandidates(a:Map, b:Map):Map
    return b if a.nil?
    it = a.entrySet.iterator
    while it.hasNext
      e = java::util::Map::Entry(it.next)
      if b.containsKey(e.getKey)
        Set(e.getValue).addAll(Set(b[e.getKey]))
      else
        it.remove
      end
    end
    a
  end

  # Returns a map of erased_candidate: invocations
  def erasedCandidateSet(types:Collection):Map
    candidates = nil
    types.each do |t|
      candidates = combineCandidates(
          candidates, erasedSupertypes(TypeMirror(t)))
    end
    candidates || Collections.emptyMap
  end

  # Removes all elements from 'candidates' that are not
  # in MEC.
  def minimizeErasedCandidates(candidates:Set):void
    minimal = HashSet.new
    cit = candidates.iterator
    while cit.hasNext
      c = TypeMirror(cit.next)
      mit = minimal.iterator
      isMinimal = true
      while mit.hasNext
        m = TypeMirror(mit.next)
        # We're using a set, so we shouldn't need to check type equality
        if @types.isSubtype(m, c)
          isMinimal = false
          break
        elsif @types.isSubtype(c, m)
          # We can't remove m from candidates, or it would invalidate cit.
          mit.remove
        end
      end
      if isMinimal
        minimal.add(c)
      end
    end
    candidates.retainAll(minimal)
  end

  def candidateInvocation(invocations:Collection):TypeMirror
    if invocations.size == 1
      TypeMirror(invocations.iterator.next)
    else
      invocations.reduce do |x:DeclaredType, y:DeclaredType|
        candidateInvocation2(x, y)
      end
    end
  end

  def candidateInvocation2(x:DeclaredType, y:DeclaredType):DeclaredType
    if x.getTypeArguments.size == 0
      return x
    elsif y.getTypeArguments.size == 0
      return y
    end
    args = TypeMirror[x.getTypeArguments.size]
    i = 0
    x.getTypeArguments.zip(y.getTypeArguments) do |a:TypeMirror, b:TypeMirror|
      args[i] = leastContainingTypeArgument(a, b)
      i += 1
    end
    @types.getDeclaredType(TypeElement(@types.asElement(x)), args)
  end

  def leastContainingTypeArgument(a:TypeMirror, b:TypeMirror)
    aw = wildcard(a)
    bw = wildcard(b)
    a_has_bounds = aw && (aw.getExtendsBound || aw.getSuperBound)
    b_has_bounds = bw && (bw.getExtendsBound || bw.getSuperBound)
    if a_has_bounds && !b_has_bounds
      return leastContainingTypeArgument(b, a)
    elsif aw && aw.getSuperBound && bw && bw.getExtendsBound
      return leastContainingTypeArgument(b, a)
    end
    if !a_has_bounds
      if !b_has_bounds
        # lcta(U, V) = U if U = V
        if @types.isSameType(a, b)
          a
        else
          # otherwise ? extends lub(U, V)
          @types.getWildcardType(leastUpperBound([a, b]), nil)
        end
      elsif bw.getExtendsBound
        # lcta(U, ? extends V) = ? extends lub(U, V)
        @types.getWildcardType(leastUpperBound([a, bw.getExtendsBound]), nil)
      else
        # lcta(U, ? super V) = ? super glb(U, V)
        @types.getWildcardType(
            nil, IntersectionType.new(@context, [a, bw.getSuperBound]))
      end
    elsif aw.getExtendsBound && bw.getExtendsBound
      # lcta(? extends U, ? extends V) = ? extends lub(U, V)
      @types.getWildcardType(
          leastUpperBound([aw.getExtendsBound, bw.getExtendsBound]), nil)
    elsif aw.getExtendsBound && bw.getSuperBound
      # lcta(? extends U, ? super V) = U if U = V
      if @types.isSameType(aw.getExtendsBound, bw.getSuperBound)
        aw.getExtendsBound
      else
        # otherwise ?
        @types.getWildcardType(nil, nil)
      end
    elsif aw.getSuperBound && bw.getSuperBound
      # lcta(? super U, ? super V) = ? super glb(U, V)
      @types.getWildcardType(
          nil, leastUpperBound([aw.getSuperBound, bw.getSuperBound]))
    else
      raise IllegalArgumentException, "lcta(#{a}, #{b})"
    end
  end

  def wildcard(type:TypeMirror):WildcardType
    if type.getKind == TypeKind.WILDCARD
      WildcardType(type)
    end
  end
end