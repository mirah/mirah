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

package org.mirah.jvm.mirrors

import java.util.Arrays
import java.util.Collections
import java.util.HashSet
import java.util.LinkedList
import java.util.List
import java.util.Set
import java.util.logging.Logger
import java.util.logging.Level
import mirah.lang.ast.Position
import org.mirah.MirahLogFormatter
import org.mirah.typer.DerivedFuture
import org.mirah.typer.ErrorType
import org.mirah.typer.InlineCode
import org.mirah.typer.MethodType
import org.mirah.typer.ResolvedType
import org.mirah.typer.TypeFuture
import org.mirah.typer.Scope
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.MemberKind
import org.jruby.org.objectweb.asm.Opcodes

class MethodLookup
  def self.initialize:void
    @@log = Logger.getLogger(MethodLookup.class.getName)
  end

  class << self
    def isSubType(subtype:ResolvedType, supertype:ResolvedType):boolean
      return true if subtype == supertype
      if subtype.kind_of?(JVMType) && supertype.kind_of?(JVMType)
        return isJvmSubType(JVMType(subtype), JVMType(supertype))
      end
      return true if subtype.matchesAnything
      return supertype.matchesAnything
    end
  
    def isJvmSubType(subtype:JVMType, supertype:JVMType):boolean
      if subtype.isPrimitive
        return supertype.isPrimitive && isPrimitiveSubType(subtype, supertype)
      end
      if subtype.kind_of?(NullType)
        return !supertype.isPrimitive
      end
      if subtype.isArray && supertype.isArray
        return isArraySubType(subtype, supertype)
      end
      super_desc = supertype.class_id
      explored = HashSet.new
      to_explore = LinkedList.new
      to_explore.add(subtype)
      until to_explore.isEmpty
        next_type = to_explore.removeFirst
        descriptor = next_type.class_id
        return true if descriptor.equals(super_desc)
        unless explored.contains(descriptor)
          explored.add(descriptor)
          to_explore.add(next_type.superclass) if next_type.superclass
          next_type.interfaces.each {|i| to_explore.add(JVMType(i.resolve))}
        end
      end
      return false
    end
  
    def isPrimitiveSubType(subtype:JVMType, supertype:JVMType):boolean
      sub_desc = subtype.class_id.charAt(0)
      super_desc = supertype.class_id.charAt(0)
      order = "BSIJFD"
      if sub_desc == super_desc
        return true
      elsif sub_desc == ?Z
        return false
      elsif sub_desc == ?C
        return order.indexOf(super_desc) > 1
      else
        return order.indexOf(super_desc) >= order.indexOf(sub_desc)
      end
    end

    def isArraySubType(subtype:JVMType, supertype:JVMType):boolean
      return true if subtype.class_id.equals(supertype.class_id)
      return false unless subtype.getAsmType.getDimensions == supertype.getAsmType.getDimensions
      component_a = subtype.getComponentType
      component_b = supertype.getComponentType
      return false if component_a.isPrimitive
      return false if component_b.isPrimitive
      isSubType(component_a, component_b)
    end

    # Returns 0, 1, -1 or NaN if a & b are the same type,
    # a < b, a > b, or neither is a subtype.
    def subtypeComparison(a:ResolvedType, b:ResolvedType):double
      if a.isError
        if b.isError
          return 0.0
        else
          return -1.0
        end
      elsif b.isError
        return 1.0
      end
      jvm_a = JVMType(a)
      jvm_b = JVMType(b)
          
      return 0.0 if jvm_a.class_id.equals(jvm_b.class_id)
      if isJvmSubType(jvm_b, jvm_a)
        return -1.0
      elsif isJvmSubType(jvm_a, jvm_b)
        return 1.0
      else
        return Double.NaN
      end
    end

    # Returns the most specific method if one exists, or the maximally
    # specific methods if the given methods are ambiguous.
    # Implements the rules in JLS 2nd edition, 15.12.2.2.
    # Notably, it does not support varargs or generic methods.
    def findMaximallySpecific(methods:List):List
      maximal = LinkedList.new
      ambiguous = false
      methods.each do |m|
        method = JVMMethod(m)
        
        # Compare 'method' with each of the maximally specific methods.
        # If it is strictly more specific than all of them, it is the
        # new most specific method.
        # If any maximally specific method is strictly more specefic than
        # 'method', it is not maximally specific.
        most_specific = true
        more_specific = true
        method_ambiguous = false
        maximal.each do |x|
          item = JVMMethod(x)
          comparison = compareSpecificity(method, item)
          @@log.finest("compareSpecificity('#{method}', '#{item}') = #{comparison}")
          if comparison < 0
            more_specific = false
            most_specific = false
            break
          elsif comparison == 0
            most_specific = false
          elsif Double.isNaN(comparison)
            most_specific = false
            method_ambiguous = true
          end
        end
        if most_specific
          maximal.clear()
          maximal.add(method)
          ambiguous = false
        elsif more_specific
          maximal.add(method)
          ambiguous = true if method_ambiguous
        end
      end
      if maximal.size > 1 && !ambiguous
        return Collections.singletonList(pickMostSpecific(maximal))
      end
      maximal
    end

    # Returns:
    #  -  < 0 if b is strictly more specific than a, including the target
    #  -  > 0 if a is strictly more specific than b, including the target
    #  -  0 if both are more specific (same override, ignoring the target)
    #  - NaN if neither is more specific (arguments are ambiguous, ignoring the target)
    # Note that methods with the same signature but from unrelated classes return 0.
    # This should only happen when at least one of the methods comes from an interface,
    # so pickMostSpecific will break the tie.
    def compareSpecificity(a:JVMMethod, b:JVMMethod):double
      raise IllegalArgumentException if a.argumentTypes.size != b.argumentTypes.size
      comparison = 0.0
      a.argumentTypes.size.times do |i|
        a_arg = ResolvedType(a.argumentTypes.get(i))
        b_arg = ResolvedType(b.argumentTypes.get(i))
        arg_comparison = subtypeComparison(a_arg, b_arg)
        return arg_comparison if Double.isNaN(arg_comparison)
        if arg_comparison != 0.0
          if comparison == 0.0
            comparison = arg_comparison
          elsif comparison != arg_comparison
            return Double.NaN
          end
        end
      end
      target_comparison = subtypeComparison(a.declaringClass, b.declaringClass)
      if comparison == target_comparison || target_comparison == 0.0
        return comparison
      elsif comparison == 0.0
        if Double.isNaN(target_comparison)
          # Return equal so pickMostSpecific gets to decide
          return comparison
        else
          return target_comparison
        end
      else
        return Double.NaN
      end
    end

    # Breaks specificity ties according the the JLS 2nd edition rules:
    #   'methods' must be a list of JVMMethods with the same signature.
    #   If one is not abstract it is returned, otherwise one is arbitrarily
    #   chosen.
    def pickMostSpecific(methods:List):JVMMethod
      method = nil
      methods.each do |m|
        method = JVMMethod(m)
        return method unless method.isAbstract
      end
      method
    end

    def findMethod(scope:Scope,
                   target:MirrorType,
                   name:String,
                   params:List,
                   macro_params:List,
                   position:Position):TypeFuture
      potentials = gatherMethods(target, name)
      state = MethodLookup.new(scope, target, potentials, position)
      state.search(params, macro_params)
      state.searchFields(name)
      @@log.fine("findMatchingMethod(#{target}.#{name}#{params}) => #{state}")
      state.future(false)
    end

    def makeFuture(target:MirrorType, method:Member, params:List,
                   position:Position):TypeFuture
      DerivedFuture.new(method.asyncReturnType) do |resolved|
        type = if resolved.kind_of?(InlineCode)
          resolved
        else
          ResolvedCall.new(target, method)
        end
        MethodType.new(method.name, params, type, method.isVararg)
      end
    end

    def inaccessible(scope:Scope, method:Member, position:Position):TypeFuture
      ErrorType.new(
          [["Cannot access #{method} from #{scope.selfType.resolve}",
            position]])
    end

    def gatherMethods(target:MirrorType, name:String):List
      methods = LinkedList.new
      types = HashSet.new
      isAbstract = (0 != (target.flags & Opcodes.ACC_ABSTRACT))
      gatherMethodsInternal(target, name, isAbstract, methods, types)
    end

    def gatherMethodsInternal(target:MirrorType, name:String, includeInterfaces:boolean, methods:List, visited:Set):List
      if target
        target = target.unmeta
      end
      unless target.nil? || target.isError || visited.contains(target)
        visited.add(target)
        methods.addAll(target.getDeclaredMethods(name))
        gatherMethodsInternal(MirrorType(target.superclass), name, includeInterfaces, methods, visited)
        if includeInterfaces
          target.interfaces.each do |i|
            iface = MirrorType(i.resolve)
            gatherMethodsInternal(iface, name, includeInterfaces, methods, visited)
          end
        end
      end
      methods
    end

    def gatherFields(target:MirrorType, name:String):List
      setter = false
      if name.endsWith('_set')
        name = name.substring(0, name.length - 4)
        setter = true
      end
      fields = LinkedList.new
      mirror = target.unmeta
      while mirror
        field = mirror.getDeclaredField(name)
        if field
          field = makeSetter(Member(field)) if setter
          fields.add(field)
        end
        mirror = mirror.superclass
      end
      fields
    end

    def makeSetter(field:Member)
      kind = if field.kind == MemberKind.FIELD_ACCESS
        MemberKind.FIELD_ASSIGN
      else
        MemberKind.STATIC_FIELD_ASSIGN
      end
      AsyncMember.new(field.flags,
                      MirrorType(field.declaringClass),
                      "#{field.name}=",
                      [field.asyncReturnType],
                      field.asyncReturnType,
                      kind)
    end

    def findMatchingMethod(potentials:List, params:List):List
      if params && params.all?
        phase1(potentials, params) || phase2(potentials, params) || phase3(potentials, params)
      end
    end

    def phase1(potentials:List, params:List):List
      arity = params.size
      phase1_methods = LinkedList.new
      potentials.each do |m|
        member = Member(m)
        args = member.argumentTypes
        next unless args.size == arity
        match = true
        arity.times do |i|
          unless isSubType(ResolvedType(params[i]), ResolvedType(args[i]))
            match = false
            break
          end
        end
        phase1_methods.add(member) if match
      end
      if phase1_methods.size == 0
        nil
      elsif phase1_methods.size > 1
        findMaximallySpecific(phase1_methods)
      else
        phase1_methods
      end
    end

    def phase2(potentials:List, params:List):List
      nil
    end

    def phase3(potentials:List, params:List):List
      nil
    end

    def isAccessible(type:JVMType, access:int, scope:Scope, target:JVMType=nil)
      return true if scope.nil?
      selfType = MirrorType(scope.selfType.resolve)
      if target && target.isMeta && (0 == (access & Opcodes.ACC_STATIC))
        return false
      elsif (0 != (access & Opcodes.ACC_PUBLIC) ||
          type.class_id.equals(selfType.class_id))
        return true
      elsif 0 != (access & Opcodes.ACC_PRIVATE)
        return false
      elsif getPackage(type).equals(getPackage(selfType))
        return true
      elsif (0 != (access & Opcodes.ACC_PROTECTED) &&
             isJvmSubType(selfType, type))
        # A subclass may call protected methods from the superclass,
        # but only on instances of the subclass.
        return target.nil? || isJvmSubType(target, selfType)
      else
        return false
      end
    end

    def getPackage(type:JVMType):String
      name = type.internal_name
      lastslash = name.lastIndexOf(?/)
      if lastslash == -1
        ""
      else
        name.substring(0, lastslash)
      end
    end

    def removeInaccessible(methods:List, scope:Scope, target:JVMType):List
      inaccessible = LinkedList.new
      it = methods.iterator
      while it.hasNext
        method = Member(it.next)
        # The declaring class and the method must be visible for the method
        # to be applicable.
        accessible = true
        accessible = false unless isAccessible(method.declaringClass, 
                                               method.declaringClass.flags,
                                               scope)
        accessible = false unless isAccessible(method.declaringClass,
                                               method.flags, scope, target)
        unless accessible
          it.remove
          inaccessible.add(method)
        end
      end
      inaccessible
    end

    def main(args:String[]):void
      logger = MirahLogFormatter.new(true).install
      @@log.setLevel(Level.ALL)
      types = MirrorTypeSystem.new
      methods = LinkedList.new
      args.each do |arg|
        methods.add(FakeMember.create(types, arg))
      end
      puts findMaximallySpecific(methods)
    end
  end

  def initialize(scope:Scope,
                 target:MirrorType,
                 potentials:List,
                 position:Position)
    @scope = scope
    @target = target
    @position = position
    setPotentials(potentials)
  end

  def setPotentials(potentials:List)
    @methods = LinkedList.new
    @macros = LinkedList.new
    @inaccessible_methods = LinkedList.new
    @inaccessible_macros = LinkedList.new
    
    potentials.each do |p|
      method = Member(p)
      # The declaring class and the method must be visible for the method
      # to be applicable.
      accessible = true
      unless MethodLookup.isAccessible(method.declaringClass, 
                                       method.declaringClass.flags,
                                       @scope)
        accessible = false
      end
      unless MethodLookup.isAccessible(method.declaringClass,
                                       method.flags, @scope, @target)
        accessible = false
      end
      
      is_macro = method.kind_of?(MacroMember)
      list = if accessible && is_macro
        @macros
      elsif accessible
        @methods
      elsif is_macro
        @inaccessible_macros
      else
        @inaccessible_methods
      end
      list.add(method)
    end
  end

  def search(params:List, macro_params:List):void
    @params = params
    @macro_params = macro_params
    @matches = MethodLookup.findMatchingMethod(@methods, params)
    @macro_matches = MethodLookup.findMatchingMethod(@macros, macro_params)
    if matches + macro_matches == 0
      @inaccessible = MethodLookup.findMatchingMethod(
          @inaccessible_methods, params)
      if @inaccessible.nil? || @inaccessible.isEmpty
        @inaccessible = MethodLookup.findMatchingMethod(
            @inaccessible_macros, macro_params)
      end
    end
  end

  def searchFields(name:String):void
    if matches + macro_matches + inaccessible == 0
      if @params.size == 0 || (name.endsWith('_set') && @params.size == 1)
        setPotentials(MethodLookup.gatherFields(@target, name))
        search(@params, nil)
      end
    end
  end

  def matches:int
    if @matches.nil?
      0
    else
      @matches.size
    end
  end

  def macro_matches:int
    if @macro_matches.nil?
      0
    else
      @macro_matches.size
    end
  end

  def inaccessible:int
    if @inaccessible.nil?
      0
    else
      @inaccessible.size
    end
  end

  def future(isField:boolean)
    if matches + macro_matches == 0
      if inaccessible
        MethodLookup.inaccessible(@scope,
                                  Member(@inaccessible.get(0)),
                                  @position)
      else
        nil
      end
    elsif matches > 0
      pickOne(@matches, @params, isField)
    else
      pickOne(@macro_matches, @macro_params, isField)
    end
  end

  def pickOne(methods:List, params:List, isField:boolean)
    if methods.size == 0
      nil
    elsif isField || methods.size == 1
      MethodLookup.makeFuture(@target, Member(methods[0]), params, @position)
    else
      ErrorType.new([["Ambiguous methods #{methods}", @position]])
    end
  end

  def toString
    if matches + macro_matches + inaccessible == 0
      "{potentials: #{@methods.size} #{@macros.size} inaccessible: #{@inaccessible_methods.size} #{@inaccessible_macros.size}}"
    else
      "{#{matches} methods #{macro_matches} macros #{inaccessible} inaccessible}"
    end
  end
end