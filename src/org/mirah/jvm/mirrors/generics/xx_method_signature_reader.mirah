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
import org.objectweb.asm.Opcodes
import org.objectweb.asm.Type
import org.objectweb.asm.signature.SignatureReader
import org.objectweb.asm.signature.SignatureVisitor
import org.mirah.jvm.types.MemberKind
import org.mirah.jvm.mirrors.Member
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.typer.BaseTypeFuture
import org.mirah.util.Context

class MethodSignatureReader < BaseSignatureReader
  def initialize(context:Context, typeVariables:Map={}):void
    super(context, typeVariables)
    @typeParams = LinkedList.new
    @params = ArrayList.new
  end

  def saveTypeParam(var)
    typeVariables[var.toString] = BaseTypeFuture.new.resolved(var)
    @typeParams.add(var)
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
    newBuilder
  end

  def getFormalTypeParameters:List
    @typeParams
  end

  def getFormalParameterTypes:List
    if @forced_params
      return @forced_params
    end
    @params.map {|p:AsyncTypeBuilder| p.future.resolve}
  end

  def genericReturnType
    MirrorType(@forced_return || @returnType.future.resolve)
  end

  def readMember(member:Member)
    # Hack!!  Currently fields also have signatures, but I'm not sure
    # how the processing of generics is different so we will just 
    # skip generic processing for field members.  FIX ME
    if member.signature and isParsable(member) 
      read(member.signature)
    else
      @forced_params = ArrayList.new(member.argumentTypes)
      @forced_return = member.returnType
    end
  end
  
  def isParsable(member:Member)
    member.kind != MemberKind.STATIC_FIELD_ACCESS and
      member.kind != MemberKind.FIELD_ACCESS
  end
end
