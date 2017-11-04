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
import java.util.List
import mirah.lang.ast.Position
import org.mirah.jvm.types.MemberKind
import org.mirah.typer.AssignableTypeFuture
import org.mirah.typer.DelegateFuture
import org.mirah.typer.DerivedFuture
import org.mirah.typer.ErrorMessage
import org.mirah.typer.ErrorType
import org.mirah.typer.ResolvedType
import org.mirah.typer.TypeFuture
import org.mirah.typer.UnreachableType
import org.mirah.util.Context

class ReturnTypeFuture < AssignableTypeFuture
  def initialize(context:Context, position:Position)
    super(position)
    @context = context
    @has_declaration = false
  end

  def setHasDeclaration(value:boolean):void
    @has_declaration = value
    checkAssignments
  end

  def hasDeclaration
    @has_declaration
  end

  def resolved(type)
    # TODO We don't support generic methods in Mirah classes
    if type && type.name.equals("null")
      type = @context[MirrorTypeSystem].loadNamedType('java.lang.Object').resolve
    elsif type.kind_of?(MirrorType)
      type = MirrorType(MirrorType(type).erasure)
    elsif type.kind_of?(UnreachableType)
      type = VoidType.new
    end
    super
  end

  def incompatibleWith(value: ResolvedType, position: Position)
    ErrorType.new([
      ErrorMessage.new("Invalid return type #{value}, expected #{inferredType}",
                       position)])
  end
end

class MirahMethod < AsyncMember implements MethodListener
  def initialize(context:Context, position:Position,
                 flags:int, klass:MirrorType, name:String,
                 argumentTypes:List /* of TypeFuture */,
                 returnType:TypeFuture, kind:MemberKind)
    super(flags, klass, name, argumentTypes,
          @return_type = ReturnTypeFuture.new(context, position), kind)
    @context = context
    @lookup = context[MethodLookup]
    @position = position
    @super_return_type = DelegateFuture.new
    @declared_return_type = returnType
    @return_type.declare(wrap(@super_return_type), position)
#   @return_type.resolved(nil)
    @return_type.error_message = "Cannot determine return type."
    @arity = argumentTypes.size
    setupOverrides(argumentTypes)
  end

  def generate_error
    @error ||= ErrorType.new([ErrorMessage.new('Does not override a method from a supertype.', @position)])
  end

  def wrap(target: TypeFuture): TypeFuture
    DerivedFuture.new(target) do |resolved|
      if resolved.kind_of?(ErrorType)
        self.wrap_error(resolved)
      else
        resolved
      end
    end
  end

  def wrap_error(type:ResolvedType):ResolvedType
    JvmErrorType.new(@context, type.as!(ErrorType))
  end

  def setupOverrides(argumentTypes:List):void
    # Should this require all args are declared or none are?
    # It seems strange to specify some args explicitly and infer
    # others from the supertypes.
    args_declared = argumentTypes.all? do |x:AssignableTypeFuture|
      x.hasDeclaration|| x.assignedValues(false, false).size > 0
    end
    if !args_declared
      declareArguments(argumentTypes)
    end
    type = MirrorType(declaringClass)
    type.addMethodListener(name, self)
    checkOverrides
  end

  def declareArguments(argumentTypes:List):void
    size = argumentTypes.size
    @arguments = DelegateFuture[size]
    size.times do |i|
      @arguments[i] = DelegateFuture.new
      @arguments[i].type = generate_error
      arg = AssignableTypeFuture(argumentTypes[i])
      # Don't declare it if it's optional or already is declared.
      unless arg.hasDeclaration || arg.assignedValues(false, false).size > 0
        arg.declare(@arguments[i], @position)
      end
    end
  end

  def methodChanged(type, name)
    checkOverrides
  end

  def checkOverrides:void
    supertype_methods = @lookup.findOverrides(
        MirrorType(declaringClass), name, @arity)
    if @arguments
      processArguments(supertype_methods)
    end
    processReturnType(supertype_methods)
  end

  def processArguments(supertype_methods:List):void
    if supertype_methods.size == 1
      method = Member(supertype_methods[0])
      @arity.times do |i|
        @arguments[i].type = method.asyncArgument(i)
      end
    else
      error = if supertype_methods.isEmpty
        generate_error
      else
        ErrorType.new([ErrorMessage.new("Ambiguous override: #{supertype_methods}", @position)])
      end
      @arguments.each do |arg|
        arg.type = error
      end
    end
  end

  def processReturnType(supertype_methods:List):void
    if @declared_return_type
      @super_return_type.type = @declared_return_type
      @return_type.setHasDeclaration(true)
      return
    end
    filtered = ArrayList.new(supertype_methods.size)
    supertype_methods.each do |method:Member|
      match = true
      self.argumentTypes.zip(method.argumentTypes) do |a:ResolvedType, b:ResolvedType|
        next if a.isError || b.isError
        unless MirrorType(a).isSameType(MirrorType(b))
          match = false
          break
        end
      end
      filtered.add(method) if match
    end
    if filtered.isEmpty
      @super_return_type.type = generate_error
#     @return_type.resolved(nil)
      @return_type.setHasDeclaration(false)
    else
      @return_type.setHasDeclaration(true)
      future = OverrideFuture.new
      filtered.each do |m:Member|
        future.addType(m.asyncReturnType)
      end
      future.addType(Member(supertype_methods[0]).asyncReturnType)
      @super_return_type.type = future
    end
  end
end