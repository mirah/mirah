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
import java.util.Map
import javax.lang.model.util.Types
import org.objectweb.asm.Opcodes
import org.objectweb.asm.Type
import org.objectweb.asm.signature.SignatureReader
import org.objectweb.asm.signature.SignatureVisitor
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.jvm.model.IntersectionType
import org.mirah.typer.TypeFuture
import org.mirah.util.Context

abstract class BaseSignatureReader < SignatureVisitor
  def initialize(context:Context, typeVariables:Map=Collections.emptyMap):void
    initialize(context, typeVariables, {})
  end

  def initialize(context:Context, typeVariables:Map, processed_signatures:Map):void
    super(Opcodes.ASM4)
    @context = context
    @typeVariables = Collections.checkedMap({}, String.class, TypeFuture.class)
    @typeVariables.putAll(typeVariables) if typeVariables
    @classbound = AsyncTypeBuilder(nil)
    @processed_signatures = processed_signatures
  end

  attr_reader typeVariables:Map

  abstract def saveTypeParam(var:TypeVariable):void; end

  def finishTypeParam
    if @typeParamName
      types = []
      if @classbound
        types.add(@classbound.future.resolve)
      end
      @interfaces.each do |i:AsyncTypeBuilder|
        types.add(i.future.resolve)
      end
      bound = if types.size == 0
        MirrorType(@context[MirrorTypeSystem].loadNamedType(
            "java.lang.Object").resolve)
      elsif types.size == 1
        MirrorType(types[0])
      else
        IntersectionType.new(@context, types)
      end
      saveTypeParam(TypeVariable.new(@context, @typeParamName, bound))
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

  def newBuilder
    AsyncTypeBuilder.new(@context, @typeVariables, @processed_signatures)
  end

  def read(signature:String):void
    reader = SignatureReader.new(signature)
    reader.accept(self)
  end

  def processed_signatures:Map
    @processed_signatures
  end
end