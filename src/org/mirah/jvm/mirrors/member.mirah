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
import java.util.Collections
import java.util.List
import org.mirah.util.Logger
import org.objectweb.asm.Opcodes
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMField
import org.mirah.jvm.types.GenericMethod
import org.mirah.jvm.types.MemberKind
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.ResolvedType
import org.mirah.typer.TypeFuture

class Member implements GenericMethod, JVMField
  def self.initialize:void
    @@log = Logger.getLogger(Member.class.getName)
  end

  def initialize(flags:int, klass:JVMType, name:String, argumentTypes:List,
                 returnType:JVMType, kind:MemberKind)
    @flags = flags
    @declaringClass = klass
    @name = name
    @argumentTypes = Collections.unmodifiableList(ArrayList.new(argumentTypes))
    @returnType = returnType
    @kind = kind
  end

  attr_reader declaringClass:JVMType, name:String, argumentTypes:List
  attr_reader returnType:JVMType, kind:MemberKind, flags:int
  attr_accessor signature:String
  attr_writer genericReturnType:JVMType

  def genericReturnType
    @genericReturnType || returnType
  end

  def asyncArgument(index:int):TypeFuture
    BaseTypeFuture.new(nil).resolved(ResolvedType(argumentTypes.get(index)))
  end

  def asyncReturnType:TypeFuture
    @returnFuture ||= BaseTypeFuture.new.resolved(@genericReturnType || @returnType)
  end

  def isStaticMethod
    @kind.name.intern == 'STATIC_METHOD'
  end

  def isInstanceMethod
    @kind.name.intern == 'METHOD'
  end

  def isStaticField
    @kind.name.intern.startsWith 'STATIC_FIELD_'
  end

  def accept(visitor, expression):void
    kind = @kind.name.intern
    if kind == 'MATH_OP'
      visitor.visitMath(self, expression)
    elsif kind == 'COMPARISON_OP'
      visitor.visitComparison(self, expression)
    elsif kind == 'METHOD'
      visitor.visitMethodCall(self, expression)
    elsif kind == 'STATIC_METHOD'
      visitor.visitStaticMethodCall(self, expression)
    elsif kind == 'FIELD_ACCESS'
      visitor.visitFieldAccess(self, expression)
    elsif kind == 'STATIC_FIELD_ACCESS'
      visitor.visitStaticFieldAccess(self, expression)
    elsif kind == 'FIELD_ASSIGN'
      visitor.visitFieldAssign(self, expression)
    elsif kind == 'STATIC_FIELD_ASSIGN'
      visitor.visitStaticFieldAssign(self, expression)
    elsif kind == 'CONSTRUCTOR'
      visitor.visitConstructor(self, expression)
    elsif kind == 'STATIC_INITIALIZER'
      visitor.visitStaticInitializer(self, expression)
    elsif kind == 'ARRAY_ACCESS'
      visitor.visitArrayAccess(self, expression)
    elsif kind == 'ARRAY_ASSIGN'
      visitor.visitArrayAssign(self, expression)
    elsif kind == 'ARRAY_LENGTH'
      visitor.visitArrayLength(self, expression)
    elsif kind == 'CLASS_LITERAL'
      visitor.visitClassLiteral(self, expression)
    elsif kind == 'INSTANCEOF'
      visitor.visitInstanceof(self, expression)
    elsif kind == 'IS_NULL'
      visitor.visitIsNull(self, expression)
    else
      raise IllegalArgumentException, "Member #{kind} not supported"
    end
  end

  def isVararg:boolean
    0 != (@flags & Opcodes.ACC_VARARGS)
  end

  def isAbstract
    0 != (@flags & Opcodes.ACC_ABSTRACT)
  end

  def toString
    result = StringBuilder.new
    result.append(declaringClass)
    if isStaticMethod
      result.append('.')
    elsif isInstanceMethod
      result.append '#'
    elsif isStaticField
      result.append '::'
    else
      result.append('.')
    end
    result.append(name)
    result.append('(')
    first = true
    argumentTypes.each do |t|
      result.append(', ') unless first
      first = false
      result.append(t)
    end
    result.append(')')
    result.toString
  end
end

class AsyncMember < Member
  def self.initialize: void
    @@log = Logger.getLogger(AsyncMember.class.getName)
  end

  def initialize(flags: int, klass: MirrorType, name: String,
                 argumentTypes: List /* of TypeFuture */,
                 returnType: TypeFuture, kind: MemberKind)
    super(flags, klass, name, Collections.emptyList, nil, kind)
    @futures = argumentTypes
    @resolvedArguments = ArrayList.new(argumentTypes.size)
    @returnType = returnType
    argumentTypes.each { |a: TypeFuture| setupArgumentListener(a) }
  end

  def argumentTypes
    Collections.unmodifiableList(@resolvedArguments)
  end

  def returnType
    # TODO: Should this convert errors?
    @returnType.resolve.as! JVMType
  end

  def asyncArgument(index)
    @futures.get(index).as! TypeFuture
  end

  def asyncReturnType
    @returnType
  end

  def setupArgumentListener(argument: TypeFuture): void
    resolvedArgs = @resolvedArguments
    index = @resolvedArguments.size

    log = @@log
    @resolvedArguments.add(argument.resolve)
    argument.onUpdate do |x, resolved|
      if resolved != resolvedArgs.get(index)
        log.fine("Argument #{index} changed from #{resolvedArgs.get(index)} to #{resolved}")
        resolvedArgs.set(index, resolved)
        self.invalidate
      end
    end
  end

  def invalidate:void
    self.declaringClass.as!(MirrorType).invalidateMethod(self.name)
  end
end
