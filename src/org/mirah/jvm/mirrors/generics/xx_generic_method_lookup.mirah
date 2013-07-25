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

import java.util.ArrayList
import java.util.Collection
import java.util.HashMap
import java.util.HashSet
import java.util.List
import java.util.Map
import java.util.logging.Level
import java.util.logging.Logger
import javax.lang.model.type.DeclaredType
import javax.lang.model.type.TypeKind
import javax.lang.model.type.TypeMirror
import javax.lang.model.util.SimpleTypeVisitor6
import javax.lang.model.util.Types
import org.mirah.jvm.mirrors.DeclaredMirrorType
import org.mirah.jvm.mirrors.Member
import org.mirah.jvm.mirrors.MethodLookup
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.typer.TypeFuture
import org.mirah.util.Context

class GenericMethodLookup
  def initialize(context:Context)
    @context = context
  end

  def self.initialize:void
    @@log = Logger.getLogger(MethodLookup.class.getName)
  end

  def processGenerics(target:MirrorType, params:List, members:List)
    result = ArrayList.new(members.size)
    members.each do |member:Member|
      if member.signature.nil?
        result.add(member)
      else
        begin
          generic_method = processMethod(member, target, params)
          if generic_method
            result.add(generic_method)
          end
        rescue => ex
          @@log.log(Level.WARNING,
                    "Error during generic method processing for #{member}",
                    ex)
          result.add(member)
        end
      end
    end
    result
  end

  def processMethod(method:Member, target:MirrorType, params:List)
    if method.signature.nil?
      return method
    end
    inference = TypeParameterInference.new(@context[Types])
    initial_vars = calculateInitialVars(inference, method, target)
    methodReader = MethodSignatureReader.new(@context, initial_vars)
    methodReader.read(method.signature)
    type_params = getTypeParams(
        target,
        methodReader.getFormalTypeParameters,
        "<init>".equals(method.name))
    generic_params = methodReader.getFormalParameterTypes
    constraint_map = collectConstraints(
        inference, type_params, generic_params, params, method.isVararg)
    solved_vars = solveConstraints(constraint_map, initial_vars)
    if methodIsApplicable(generic_params, params, solved_vars)
      return substituteReturnType(method, methodReader.genericReturnType, solved_vars)
    else
      return nil
    end
  end

  def getTypeParams(target:MirrorType, type_params:Collection, isInit:boolean)
    if target.kind_of?(DeclaredMirrorType) && isInit
      result = HashSet.new
      result.addAll(DeclaredMirrorType(target).getTypeVariableMap.values)
      result.addAll(type_params)
      result
    else
      type_params
    end
  end

  def collectConstraints(inference:TypeParameterInference,
                         type_params:Collection,
                         generic_params:List,
                         params:List,
                         isVararg:boolean):Map
    arg_count = generic_params.size
    required_count = isVararg ? arg_count - 1 : arg_count
    constraint_map = {}
    type_params.each do |v:TypeVariable|
      constraint_map[v] = Constraints.new
    end
    vararg_component = nil
    i = 0
    params.zip(generic_params) do |argument:TypeMirror, param:TypeMirror|
      if param.nil?
        inference.processArgument(argument, ?<, vararg_component,
                                  constraint_map)
      elsif i == required_count
        vararg = MirrorType(param)
        if vararg.isSupertypeOf(MirrorType(argument))
          inference.processArgument(argument, ?<, param, constraint_map)
        else
          vararg_component = MirrorType(vararg.getComponentType)
          inference.processArgument(argument, ?<, vararg_component,
                                    constraint_map)
        end
      end
      inference.processArgument(argument, ?<, param, constraint_map)
    end
    constraint_map
  end

  def calculateInitialVars(inference:TypeParameterInference,
                           method:Member, target:MirrorType)
    result = {}
    if target.isMeta
      return result
    end
    generic_target = DeclaredMirrorType(inference.findMatchingSupertype(
        target, DeclaredType(method.declaringClass)))
    vars = generic_target.getTypeVariableMap
    vars.keySet.each do |k|
      result[k.toString] = vars[k]
    end
    result
  end

  def solveConstraints(constraints:Map, initial:Map):Map
    solved = {}
    initial.keySet.each do |k|
      solved[k] = TypeFuture(initial[k]).resolve
    end
    # process equality constraints first
    constraints.keySet.each do |tv|
      c = Constraints(constraints[tv])
      c.getEqual.each do |t:TypeMirror|
        if t.getKind == TypeKind.TYPEVAR
          next if t.toString.equals(tv.toString)
        end
        solved[tv.toString] = t
      end
    end
    simplifyConstraints(solved)
    constraints.keySet.each do |tv|
      c = Constraints(constraints[tv])
      unless c.getExtends.isEmpty
        finder = LubFinder.new(@context[Types])
        solved[tv.toString] = finder.leastUpperBound(c.getExtends)
        simplifyConstraints(solved)
      end
    end
    solved
  end

  # Replace references to solved typevars with the solution
  def simplifyConstraints(typevars:Map):void
    updates = {}
    typevars.keySet.each do |k|
      v = TypeMirror(typevars[k])
      while v.getKind == TypeKind.TYPEVAR && typevars.containsKey(v.toString)
        new_v = TypeMirror(typevars[v.toString])
        break if new_v == v
        v = new_v
        updates[k] = v
      end
    end
    typevars.putAll(updates)
  end

  def substituteTypeVariables(type:TypeMirror, typevars:Map):MirrorType
    visitor = Substitutor.new(@context, typevars)
    MirrorType(visitor.visit(type))
  end

  def substituteReturnType(method:Member, returnType:TypeMirror, typevars:Map):Member
    newReturnType = substituteTypeVariables(
        TypeMirror(returnType), typevars)
    if newReturnType == returnType
      method
    else
      newMember = Member.new(
          method.flags, method.declaringClass, method.name,
          method.argumentTypes, method.returnType, method.kind)
      newMember.genericReturnType = newReturnType
      newMember
    end
  end

  def methodIsApplicable(params:List, args:List, typevars:Map)
    params.zip(args) do |param:TypeMirror, arg:MirrorType|
      unless substituteTypeVariables(param, typevars).assignableFrom(arg)
        return false
      end
    end
    true
  end
end