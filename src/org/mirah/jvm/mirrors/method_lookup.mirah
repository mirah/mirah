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

import java.util.ArrayList
import java.util.Arrays
import java.util.Collections
import java.util.HashSet
import java.util.LinkedList
import java.util.List
import java.util.Map
import java.util.Set
import java.util.logging.Level
import org.mirah.util.Logger
import mirah.lang.ast.Position
import org.objectweb.asm.Opcodes
import org.mirah.MirahLogFormatter
import org.mirah.jvm.mirrors.generics.GenericMethodLookup
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMTypeUtils
import org.mirah.jvm.types.MemberKind
import org.mirah.jvm.mirrors.debug.DebuggerInterface
import org.mirah.typer.DerivedFuture
import org.mirah.typer.ErrorType
import org.mirah.typer.ErrorMessage
import org.mirah.typer.InlineCode
import org.mirah.typer.MethodType
import org.mirah.typer.ResolvedType
import org.mirah.typer.Scope
import org.mirah.typer.TypeFuture
import org.mirah.util.Context


interface SubtypeChecker
  def isSubType(subtype:ResolvedType, supertype:ResolvedType):boolean; end
end

class Phase1Checker implements SubtypeChecker
  def isSubType(subtype, supertype)
    MethodLookup.isSubType(subtype, supertype)
  end
end

class Phase2Checker implements SubtypeChecker
  def isSubType(subtype, supertype)
    MethodLookup.isSubTypeWithConversion(subtype, supertype)
  end
end

class DebugError < ErrorType
  def initialize(messages: List, context: Context, state: LookupState)
    super(messages)
    if context[DebuggerInterface]
      @state = state
    end
  end
end

class MethodLookup
  def self.initialize:void
    @@log = Logger.getLogger(MethodLookup.class.getName)
  end

  def initialize(context:Context)
    @context = context
  end

  class << self
    def isPrimitive(type:JVMType)
      JVMTypeUtils.isPrimitive(type)
    end

    def isArray(type:JVMType)
      JVMTypeUtils.isArray(type)
    end

    def isSubType(subtype:ResolvedType, supertype:ResolvedType):boolean
      import static org.mirah.util.Comparisons.*
      return true if areSame(subtype, supertype)
      return true if subtype.equals(supertype)
      if subtype.kind_of?(JVMType) && supertype.kind_of?(JVMType)
        return isJvmSubType(JVMType(subtype), JVMType(supertype))
      end
      return true if subtype.matchesAnything
      return supertype.matchesAnything
    end

    def isJvmSubType(subtype:JVMType, supertype:JVMType):boolean
      return true if (subtype.matchesAnything || supertype.matchesAnything)
      if "null".equals(subtype.name)
        return !isPrimitive(supertype)
      end
      if subtype.isBlock
        return true if JVMTypeUtils.isInterface(supertype)
        return true if JVMTypeUtils.isAbstract(supertype)
      end
      MirrorType(supertype).isSupertypeOf(MirrorType(subtype))
    end

    def isPrimitiveSubType(subtype:JVMType, supertype:JVMType):boolean
      MirrorType(supertype).isSupertypeOf(MirrorType(subtype))
    end

    def isArraySubType(subtype:JVMType, supertype:JVMType):boolean
      MirrorType(supertype).isSupertypeOf(MirrorType(subtype))
    end

    def isSubTypeWithConversion(subtype:ResolvedType,
                                supertype:ResolvedType):boolean
      if isSubType(subtype, supertype)
        true
      elsif subtype.kind_of?(JVMType) && supertype.kind_of?(JVMType)
        isSubTypeViaBoxing(JVMType(subtype), JVMType(supertype))
      else
        false
      end
    end

    def isSubTypeViaBoxing(subtype:JVMType, supertype:JVMType)
      if isPrimitive(subtype)
        if subtype.box
          return isJvmSubType(subtype.box, supertype)
        end
      elsif subtype.unbox
        return isJvmSubType(subtype.unbox, supertype)
      end
      false
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
      jvm_a = MirrorType(a)
      jvm_b = MirrorType(b)
        
      return 0.0 if jvm_a.isSameType(jvm_b)

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
    def findMaximallySpecific(methods:List, params:List):List
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
          comparison = compareSpecificity(method, item, params)
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
    def compareSpecificity(a:JVMMethod, b:JVMMethod, params:List):double
      last_a = a.argumentTypes.size - 1
      last_b = b.argumentTypes.size - 1
      raise IllegalArgumentException if (last_a != last_b && !(a.isVararg && b.isVararg) )
      comparison = 0.0
      Math.max(a.argumentTypes.size, b.argumentTypes.size).times do |i|
        a_arg = getMethodArgument(a.argumentTypes, i, a.isVararg)
        b_arg = getMethodArgument(b.argumentTypes, i, b.isVararg)
        arg_comparison = subtypeComparison(a_arg, b_arg)
        if params[i].kind_of?(NullType)
          arg_comparison *= -1
        end
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

    def getMethodArgument(arguments:List, index:int, isVararg:boolean)
      last_index = arguments.size - 1
      if isVararg && index >= last_index
        type = ResolvedType(arguments.get(last_index))
        if type.isError
          type
        else
          JVMType(type).getComponentType
        end
      else
        ResolvedType(arguments.get(index))
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
  end

  def findMethod(scope:Scope,
                 target:MirrorType,
                 name:String,
                 params:List,
                 macro_params:List,
                 position:Position,
                 includeStaticImports:boolean):TypeFuture
    potentials = gatherMethods(target, name)

    if includeStaticImports && potentials.isEmpty
      potentials = gatherStaticImports(MirrorScope(scope), name)
    end
    state = LookupState.new(@context, scope, target, potentials, position)
    state.search(params, macro_params)
    state.searchFields(name)
    @@log.fine("findMethod(#{target}.#{name}#{params}) => #{state}")
    state.future(false)
  end

  def findOverrides(target:MirrorType, name:String, arity:int):List  # <Member>
    results = {}
    unless target.isMeta
      gatherMethods(target, name).each do |m|
        member = Member(m)
        next if member.declaringClass == target
        next if member.kind_of?(MacroMember)
        member_is_static = (0 != member.flags & Opcodes.ACC_STATIC)
        if member.argumentTypes.size == arity
          results[[member.argumentTypes, member.asyncReturnType.resolve]] = member
        end
      end
    end
    ArrayList.new(results.values)
  end

  def makeFuture(target:MirrorType, method:Member, params:List,
                 position:Position, state:LookupState):TypeFuture
    if @context[DebuggerInterface].nil?
      state = nil
    end

    DerivedFuture.new(method.asyncReturnType) do |resolved|
      x = state  # capture state for debugging
      type = if resolved.kind_of?(InlineCode)
        resolved
      else
        ResolvedCall.create(target, method)
      end
      MethodType.new(method.name, method.argumentTypes, type, method.isVararg)
    end
  end

  def inaccessible(scope:Scope, method:Member, position:Position, state:LookupState):TypeFuture
    DebugError.new(
        [ErrorMessage.new("Cannot access #{method} from #{scope.selfType.resolve}", position)],
        @context, state)
  end

  def gatherMethods(target:MirrorType, name:String):List
    methods = LinkedList.new
    types = HashSet.new
    gatherMethodsInternal(target, name, methods, types)
  end

  def gatherStaticImports(scope:MirrorScope, name:String):List
    methods = LinkedList.new
    fields = ArrayList.new
    types = HashSet.new
    scope.staticImports.each do |type|
      resolved = TypeFuture(type).resolve
      if resolved.kind_of?(MirrorType)
        gatherMethodsInternal(MirrorType(resolved), name, methods, types)
        gatherFields(MirrorType(resolved), name, fields)
      end
    end
    cflags = Opcodes.ACC_PUBLIC | Opcodes.ACC_STATIC
    fields.each do |f:Member|
      methods.add f if f.flags & cflags == cflags
    end
    methods
  end

  def gatherMethodsInternal(target:MirrorType, name:String, methods:List, visited:Set):List
    if target
      target = target.unmeta
    end
    unless target.nil? || target.isError || visited.contains(target)
      visited.add(target)
      methods.addAll(target.getDeclaredMethods(name))
      return methods if "<init>".equals(name)
      target.directSupertypes.each do |t|
        gatherMethodsInternal(MirrorType(t), name, methods, visited)
      end
    end
    methods
  end

  def gatherAbstractMethods(target:MirrorType):List
    defined_methods = HashSet.new
    abstract_methods = { }
    visited = HashSet.new
    gatherAbstractMethodsInternal(target, defined_methods, abstract_methods, visited)
    abstract_methods.keySet.removeAll(defined_methods)
    ArrayList.new(abstract_methods.values)
  end

  def gatherAbstractMethodsInternal(target:MirrorType, defined_methods:Set, abstract_methods:Map, visited:Set):void
    if target
      target = target.unmeta
    end
    unless target.nil? || target.isError || visited.contains(target)
      visited.add(target)
      target.getAllDeclaredMethods.each do |member: JVMMethod|
        if member.isAbstract
          type = MethodType.new(member.name, member.argumentTypes, member.returnType, member.isVararg)
          abstract_methods[[member.name, member.argumentTypes]] = type
        else
          defined_methods.add([member.name, member.argumentTypes])
        end
      end
      target.directSupertypes.each do |t|
        gatherAbstractMethodsInternal(MirrorType(t), defined_methods, abstract_methods, visited)
      end
    end
  end

  def gatherFields(target:MirrorType, name:String, fields: List = LinkedList.new):List
    setter = false
    if name.endsWith('_set')
      name = name.substring(0, name.length - 4)
      setter = true
    end
    mirror = target.unmeta
    gatherFieldsInternal(target, name, setter, fields, HashSet.new)
    fields
  end

  def gatherFieldsInternal(target:MirrorType, name:String,
                           isSetter:boolean, fields:List, visited:Set):void
    unless target.nil? || target.isError || visited.contains(target)
      visited.add(target)
      field = target.getDeclaredField(name)
      if field
        field = makeSetter(Member(field)) if isSetter
        fields.add(field)
      end
      target.directSupertypes.each do |t|
        gatherFieldsInternal(MirrorType(t), name, isSetter, fields, visited)
      end
    end
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
    if  params && !potentials.isEmpty && params.all?
      phase1(potentials, params) || phase2(potentials, params) || phase3(potentials, params)
    end
  end

  def phase1(potentials:List, params:List):List
    findMatchingArityMethod(Phase1Checker.new, potentials, params)
  end
  
  def findMatchingArityMethod(phase:SubtypeChecker,
                              potentials:List,
                              params:List)
    arity = params.size
    phase_methods = LinkedList.new
    potentials.each do |m|
      member = Member(m)
      args = member.argumentTypes
      next unless args.size == arity
      match = true
      arity.times do |i|
        unless phase.isSubType(ResolvedType(params[i]), ResolvedType(args[i]))
          match = false
          break
        end
      end
      phase_methods.add(member) if match
    end
    if phase_methods.size == 0
      nil
    elsif phase_methods.size > 1
      MethodLookup.findMaximallySpecific(phase_methods, params)
    else
      phase_methods
    end
  end

  def phase2(potentials:List, params:List):List
    findMatchingArityMethod(Phase2Checker.new, potentials, params)
  end

  def phase3(potentials:List, params:List):List
    arity = params.size
    phase3_methods = LinkedList.new
    potentials.each do |m|
      member = Member(m)
      next unless member.isVararg
      args = member.argumentTypes
      required_count = args.size - 1
      next unless required_count <= arity
      match = true
      arity.times do |i|
        param = ResolvedType(params[i])
        arg = MethodLookup.getMethodArgument(args, i, true)
        unless MethodLookup.isSubTypeWithConversion(param, arg)
          match = false
          break
        end
      end
      phase3_methods.add(member) if match
    end
    if phase3_methods.size == 0
      nil
    elsif phase3_methods.size > 1
      MethodLookup.findMaximallySpecific(phase3_methods, params)
    else
      phase3_methods
    end
  end

  def self.isAccessible(type:JVMType, access:int, scope:Scope, target:JVMType=nil)
    return true if scope.nil?
    if target && target.isMeta && (0 == (access & Opcodes.ACC_STATIC))
      return false
    elsif scope.nil? || scope.selfType.nil?
      return 0 != (access & Opcodes.ACC_PUBLIC)
    end
    selfType = MirrorType(scope.selfType.peekInferredType)
    if (0 != (access & Opcodes.ACC_PUBLIC) ||
        type.getAsmType.getDescriptor.equals(
            selfType.getAsmType.getDescriptor))
      true
    elsif 0 != (access & Opcodes.ACC_PRIVATE)
      false
    elsif getPackage(type).equals(getPackage(selfType))
      true
    elsif (0 != (access & Opcodes.ACC_PROTECTED) &&
           MethodLookup.isJvmSubType(selfType, type))
      # A subclass may call protected methods from the superclass,
      # but only on instances of the subclass.
      # NOTE: There's no way to differentiate between a call to super
      # or just trying to access protected methods on a random instance
      # of the superclass. For now I guess we just allow both and let
      # the latter raise a runtime exception.
      true
      #return target.nil? || MethodLookup.isJvmSubType(target, selfType)
    else
      false
    end
  end

  def self.getPackage(type:JVMType):String
    name = type.getAsmType.getInternalName
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
      accessible = false unless MethodLookup.isAccessible(
          method.declaringClass, method.declaringClass.flags, scope)
      accessible = false unless MethodLookup.isAccessible(
          method.declaringClass, method.flags, scope, target)
      unless accessible
        it.remove
        inaccessible.add(method)
      end
    end
    inaccessible
  end

  def self.main(args:String[]):void
    logger = MirahLogFormatter.new(true).install
    @@log.setLevel(Level.ALL)
    types = MirrorTypeSystem.new
    methods = LinkedList.new
    args.each do |arg|
      methods.add(FakeMember.create(types, arg))
    end
    puts findMaximallySpecific(methods, [])
  end
end

class LookupState
  def initialize(context:Context,
                 scope:Scope,
                 target:MirrorType,
                 potentials:List,
                 position:Position)
    @context = context
    @scope = scope
    @target = target
    @position = position
    setPotentials(potentials)
  end

  def processGenericMethods
    generics = GenericMethodLookup.new(@context)
    @matches = generics.processGenerics(@target, @params, @matches)
  end

  def setPotentials(potentials:List)
    # Save the old state for debugging.
    @saved_methods = @methods
    @saved_macros = @macros
    @saved_inaccessible_methods = @inaccessible_methods
    @saved_inaccessible_macros = @inaccessible_macros
    
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
    lookup = @context[MethodLookup]
    @matches = lookup.findMatchingMethod(@methods, params)
    @macro_matches = lookup.findMatchingMethod(@macros, macro_params)
    if matches > 0
      # These methods match using the raw signature, but they
      # may not actually be applicable using generics
      # (in which case there would probably be a ClassCastException
      # at runtime).
      # Since this can bring us down to 0 applicable methods, we need
      # to process generics before inaccessible methods
      processGenericMethods
    end
    if matches + macro_matches == 0
      @inaccessible = lookup.findMatchingMethod(@inaccessible_methods, params)
      if @inaccessible.nil? || @inaccessible.isEmpty
        @inaccessible = lookup.findMatchingMethod(
            @inaccessible_macros, macro_params)
      end
    end
  end

  def searchFields(name:String):void
    if matches + macro_matches + inaccessible == 0
      if @params.size == 0 || (name.endsWith('_set') && @params.size == 1)
        setPotentials(@context[MethodLookup].gatherFields(@target, name))
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
      if inaccessible != 0
        @context[MethodLookup].inaccessible(
            @scope, Member(@inaccessible.get(0)), @position, self)
      elsif @context[DebuggerInterface]
        DebugError.new([ErrorMessage.new("Can't find method #{@target}#{@params} II #{@methods}")],
                       @context,
                       self)
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
      @context[MethodLookup].makeFuture(
          @target, Member(methods[0]), params, @position, self)
    else
      DebugError.new([ErrorMessage.new("Ambiguous methods #{methods}", @position)], @context, self)
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