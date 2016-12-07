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

import java.util.Collections
import java.util.LinkedList
import java.util.List
import java.util.Map
import org.mirah.util.Logger
import javax.lang.model.element.TypeElement
import javax.lang.model.type.DeclaredType
import javax.lang.model.type.TypeMirror
import javax.lang.model.util.Types
import org.objectweb.asm.Opcodes
import org.objectweb.asm.Type
import org.objectweb.asm.signature.SignatureReader
import org.objectweb.asm.signature.SignatureVisitor
import org.mirah.jvm.mirrors.DeclaredMirrorType
import org.mirah.jvm.mirrors.MirrorLoader
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.jvm.model.Cycle
import org.mirah.jvm.model.IntersectionType
import org.mirah.typer.TypeFuture
import org.mirah.typer.BaseTypeFuture
import org.mirah.util.Context

class IgnoredTypeBuilder < SignatureVisitor
  def initialize
    super(Opcodes.ASM4)
  end
end

class AbstractTypeInvoker < BaseSignatureReader
  def initialize(context:Context, typeVars:Map, args:List, processed_signatures:Map)
    super(context, typeVars, processed_signatures)
    @interfaces = []
  end

  def getTypeVariableMap:Map
    typeVariables
  end

  def visitSuperclass
    finishTypeParam
    @superclass = newBuilder
  end

  def visitInterface
    builder = newBuilder
    @interfaces.add(builder)
    builder
  end

  def superclass
    if @superclass
      @superclass.future
    else
      nil
    end
  end

  def interfaces
    array = TypeFuture[@interfaces.size]
    it = @interfaces.iterator
    @interfaces.size.times do |i|
      array[i] = AsyncTypeBuilder(it.next).future
    end
    array
  end
end

class GenericsCapableSignatureReader  < AbstractTypeInvoker
  def initialize(context:Context)
    super(context, nil, [], {})
    @typeParams = LinkedList.new
  end
  
  def saveTypeParam(var)
    @typeParams.add(var)
  end

  def getFormalTypeParameters:List
    @typeParams
  end
end


class TypeInvoker < AbstractTypeInvoker
  def initialize(context:Context, typeVars:Map, args:List, processed_signatures:Map)
    super
    @args = LinkedList.new(args)
  end
  
  def saveTypeParam(var)
    typeVariables[var.toString] = @args.removeFirst
  end

  def self.invoke(context:Context, type:MirrorType, args:List,
                  outerTypeArgs:Map, processed_signatures:Map):MirrorType
    dtype = DeclaredMirrorType(type)
    if dtype.signature.nil? || args.any? {|a| a.nil?}
      type
    else
      invoker = TypeInvoker processed_signatures[dtype.signature]
      unless invoker
        invoker = TypeInvoker.new(context, outerTypeArgs, args, processed_signatures)
        processed_signatures[dtype.signature] = invoker
        invoker.read(dtype.signature)
      end
      TypeInvocation.new(context, type,
                        invoker.superclass, invoker.interfaces, args,
                        invoker.getTypeVariableMap)
    end
  end
end

