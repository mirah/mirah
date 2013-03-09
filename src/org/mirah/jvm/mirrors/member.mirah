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
import org.jruby.org.objectweb.asm.Opcodes
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.MemberKind
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.TypeFuture

class Member implements JVMMethod
  def initialize(flags:int, klass:JVMType, name:String, argumentTypes:List, returnType:JVMType, kind:MemberKind)
    @flags = flags
    @declaringClass = klass
    @name = name
    @argumentTypes = Collections.unmodifiableList(ArrayList.new(argumentTypes))
    @returnType = returnType
    @kind = kind
  end
  
  attr_reader declaringClass:JVMType, name:String, argumentTypes:List
  attr_reader returnType:JVMType, kind:MemberKind, flags:int

  def asyncReturnType:TypeFuture
    @returnFuture ||= BaseTypeFuture.new.resolved(@returnType)
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
    result.append('.')
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
  def initialize(flags:int, klass:JVMType, name:String, argumentTypes:List, returnType:TypeFuture, kind:MemberKind)
    super(flags, klass, name, argumentTypes, nil, kind)
    @returnType = returnType
  end

  def returnType
    # TODO: Should this convert errors?
    JVMType(@returnType.resolve)
  end

  def asyncReturnType
    @returnType
  end
end
