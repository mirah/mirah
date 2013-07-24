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
import java.util.HashMap
import java.util.LinkedList
import java.util.List
import java.util.Map
import javax.lang.model.util.Types
import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.Type
import org.jruby.org.objectweb.asm.signature.SignatureReader
import org.jruby.org.objectweb.asm.signature.SignatureVisitor
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.typer.BaseTypeFuture
import org.mirah.util.Context

class MethodSignatureReader < SignatureVisitor
  def initialize(context:Context, typeVariables:Map={}):void
    super(Opcodes.ASM4)
    @context = context
    @typeVariables = HashMap.new(typeVariables)
    @typeParams = LinkedList.new
    @params = ArrayList.new
    @classbound = AsyncTypeBuilder(nil)
  end

  def finishTypeParam
    if @typeParamName
      types = []
      if @classbound
        types.add(@classbound.future.resolve)
      end
      @interfaces.each do |i:AsyncTypeBuilder|
        types.add(@classbound.future.resolve)
      end
      bound = if types.size == 0
        MirrorType(@context[MirrorTypeSystem].loadNamedType(
            "java.lang.Object").resolve)
      elsif types.size == 1
        MirrorType(types[0])
      else
        IntersectionType.new(types)
      end
      var = TypeVariable.new(@context[Types], @typeParamName, bound)
      @typeVariables[@typeParamName] = BaseTypeFuture.new.resolved(var)
      @typeParams.add(var)
    end
    @typeParamName = String(nil)
  end

  def visitFormalTypeParameter(name)
    finishTypeParam
    @typeParamName = name
    @classbound = nil
    @interfaces = []
  end
  def visitClassBound
    @classbound = newBuilder
  end
  def visitInterfaceBound
    builder = newBuilder
    @interfaces.add(builder)
    builder
  end
  def visitParameterType
    finishTypeParam
    builder = newBuilder
    @params.add(builder)
    builder
  end
  def visitReturnType
    finishTypeParam
    @returnType = newBuilder
  end
  def visitExceptionType
    finishTypeParam
    newBuilder
  end

  def newBuilder
    AsyncTypeBuilder.new(@context, @typeVariables)
  end

  def getFormalTypeParameters:List
    @typeParams
  end

  def getFormalParameterTypes:List
    @params.map {|p:AsyncTypeBuilder| p.future.resolve}
  end

  def genericReturnType
    MirrorType(@returnType.future.resolve)
  end

  def read(signature:String):void
    reader = SignatureReader.new(signature)
    reader.accept(self)
  end
end
