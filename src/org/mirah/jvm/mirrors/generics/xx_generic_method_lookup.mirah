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
import java.util.Collections
import java.util.HashMap
import java.util.HashSet
import java.util.List
import java.util.Map
import java.util.Set
import java.util.logging.Level
import java.util.logging.Logger
# import org.mirah.util.Logger # the old compiler is not ready for this
import javax.lang.model.type.DeclaredType
import javax.lang.model.type.TypeKind
import javax.lang.model.type.TypeMirror
import javax.lang.model.util.SimpleTypeVisitor6
import javax.lang.model.util.Types
import org.mirah.jvm.mirrors.DeclaredMirrorType
import org.mirah.jvm.mirrors.Member
import org.mirah.jvm.mirrors.MethodLookup
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.jvm.types.JVMType
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.GenericTypeFuture
import org.mirah.typer.TypeFuture
import org.mirah.typer.ErrorType
import org.mirah.typer.ResolvedType
import org.mirah.util.Context

class GenericMethodLookup
  def initialize(context:Context)
    @context = context
    @types = @context[MirrorTypeSystem]
  end

  def self.initialize:void
    @@log = Logger.getLogger(MethodLookup.class.getName)
  end

  def processGenerics(target:MirrorType, params:List, members:List)
    if params.any? {|x:ResolvedType| x.nil? || x.isError}
      return members
    end
    result = ArrayList.new(members.size)
    members.each do |member:Member|
      generic_constructor = ("<init>".equals(member.name) && target.unmeta.kind_of?(DeclaredMirrorType) && DeclaredMirrorType(target.unmeta).signature)
      if member.signature.nil? && !generic_constructor
        result.add(member)
      else
        begin
          generic_method = processMethod(member, target, params)
          if generic_method
            result.add(generic_method)
          end
        rescue Throwable => ex
          @@log.log(Level.WARNING,
                    "Error during generic method processing for #{member}",
                    ex)
          result.add(member)
        end
      end
    end
    result
  end

  def processMethod(method:Member, target:MirrorType, params:List):Member
    inference = TypeParameterInference.new(@context[Types])
    initial_vars = calculateInitialVars(inference, method, target)
    methodReader = readMethodSignature(method, initial_vars)
    type_params = getTypeParams(
        target,
        methodReader.getFormalTypeParameters,
        "<init>".equals(method.name))
    initial_vars.putAll(type_params)
    generic_params = methodReader.getFormalParameterTypes
    constraint_map = collectConstraints(
        inference, findUnsolved(initial_vars), generic_params, params, method.isVararg)
    solved_vars = solveConstraints(constraint_map, initial_vars)
    lockSolutions(solved_vars, type_params.keySet)
    if methodIsApplicable(generic_params, params, solved_vars, method.isVararg)
      return substituteReturnType(method, methodReader.genericReturnType, solved_vars)
    else
      return nil
    end
  end

  def readMethodSignature(method:Member, typevar_futures:Map)
    new_map = HashMap.new
    typevar_futures.keySet.each do |k:String|
      future = TypeFuture(typevar_futures[k])
      if future.kind_of?(GenericTypeFuture)
        # This is an unsolved variable. Create a type variable so we can try
        # to infer its type.


        if future.resolve.kind_of?(ErrorType)
          # TODO figure out how to exercise this with a test
          raise "attempting to resolve a generic type failed for #{method} #{future.resolve}"
        end

        new_map[k] = BaseTypeFuture.new.resolved(
            TypeVariable.new(@context, k, MirrorType(future.resolve)))
      else
        new_map[k] = future
      end
    end
    methodReader = MethodSignatureReader.new(@context, new_map)
    methodReader.readMember(method)
    methodReader
  end

  def getTypeParams(target:MirrorType, type_params:Collection, isInit:boolean)
    result = Collections.checkedMap(HashMap.new, String.class, TypeFuture.class)
    if target.kind_of?(DeclaredMirrorType) && isInit
      DeclaredMirrorType(target).getTypeVariableMap.values.each do |x:TypeFuture|
        tv = TypeVariable(x.resolve)
        result[tv.toString] = GenericTypeFuture.new(
            nil, MirrorType(tv.getUpperBound))
      end
    end
    type_params.each do |tv:TypeVariable|
      result[tv.toString] = GenericTypeFuture.new(
          nil, MirrorType(tv.getUpperBound))
    end
    result
  end

  def findUnsolved(initial_vars:Map):Set
    unsolved = HashSet.new
    initial_vars.keySet.each do |k|
      v = initial_vars[k]
      if v.kind_of?(GenericTypeFuture)
        unsolved.add(k)
      end
    end
    unsolved
  end

  def collectConstraints(inference:TypeParameterInference,
                         type_params:Collection,
                         generic_params:List,
                         params:List,
                         isVararg:boolean):Map
    arg_count = generic_params.size
    required_count = isVararg ? arg_count - 1 : arg_count
    constraint_map = Collections.checkedMap(
        {}, String.class, Constraints.class)
    type_params.each do |v|
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
        target, DeclaredMirrorType(method.declaringClass)))
    if generic_target.nil?
      # This happens for static imports.
      return result
    end
    vars = generic_target.getTypeVariableMap
    vars.keySet.each do |k|
      result[k.toString] = vars[k]
    end
    result
  end

  def newInvocation(type:JVMType, typevars:Map)
    if type.kind_of?(DeclaredMirrorType)
      declared = DeclaredMirrorType(type)
      vars = declared.getTypeVariableMap
      unless vars.isEmpty
        args = ArrayList.new(vars.size)
        vars.keySet.each do |k|
          args.add(typevars[k])
        end
        return @types.parameterize(BaseTypeFuture.new.resolved(type), args).resolve
      end
    end
    type
  end

  def solveConstraints(constraints:Map, solved:Map):Map
    # This isn't quite right. If we're inferring arguments on the target,
    # we will apply anything we've learned from this invocation. However,
    # we may later decide that this invocation isn't applicable or is ambiguous.

    # Process equality constraints first.
    constraints.keySet.each do |tv|
      c = Constraints(constraints[tv])
      c.getEqual.each do |t:MirrorType|
        if t.getKind == TypeKind.TYPEVAR
          next if t.toString.equals(tv.toString)
        end
        tv_future = GenericTypeFuture(solved[tv])
        t_future = GenericTypeFuture(solved[t])
        if t_future
          tv_future.assign(t_future, nil)
        else
          tv_future.resolved(t)
        end
      end
    end
    constraints.keySet.each do |tv|
      c = Constraints(constraints[tv])
      future = GenericTypeFuture(solved[tv])
      c.getSuper.each do |result:MirrorType|
        future.assign(BaseTypeFuture.new.resolved(result), nil)
      end
    end
    solved
  end

  def lockSolutions(solved:Map, lockable:Collection):void
    lockable.each do |k|
      future = GenericTypeFuture(solved[k])
      if future.isResolved
        solved[k] = BaseTypeFuture.new.resolved(future.resolve)
      end
    end
  end

  def substituteTypeVariables(type:TypeMirror, typevars:Map):MirrorType
    visitor = Substitutor.new(@context, typevars)
    future = TypeFuture(visitor.visit(type))
    MirrorType(future.resolve)
  end

  def substituteReturnType(method:Member, returnType:TypeMirror, typevars:Map):Member
    newReturnType = if "<init>".equals(method.name)
      newInvocation(method.declaringClass, typevars)
    else
      substituteTypeVariables(returnType, typevars)
    end
    if newReturnType == method.genericReturnType
      method
    else
      newMember = Member.new(
          method.flags, method.declaringClass, method.name,
          method.argumentTypes, method.returnType, method.kind)
      newMember.genericReturnType = MirrorType(newReturnType)
      newMember
    end
  end

  def methodIsApplicable(params:List, args:List, typevars:Map, isVararg:boolean)
    required_count = if isVararg
      params.size - 1
    else
      -1
    end
    vararg_component = nil
    i = 0
    args.zip(params) do |arg:MirrorType, param:TypeMirror|
      if param.nil?
        unless vararg_component.assignableFrom(arg)
          return false
        end
      else
        substituted = substituteTypeVariables(param, typevars)
        if i == required_count 
          vararg = MirrorType(substituted)
          unless args.size == params.size && vararg.assignableFrom(arg)
            vararg_component = MirrorType(vararg.getComponentType)
            unless vararg_component.assignableFrom(arg)
              return false
            end
          end
        else
          unless substituted.assignableFrom(arg)
            return false
          end
        end
      end
    end
    true
  end
end