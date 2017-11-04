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

import javax.lang.model.type.TypeKind
import javax.lang.model.type.ErrorType as ErrorTypeModel
import java.util.Collections
import java.util.List
import org.mirah.typer.ErrorType
import org.mirah.typer.TypeFuture
import org.objectweb.asm.Opcodes
import org.objectweb.asm.Type
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMMethod
import org.mirah.util.Context

class JvmErrorType < ErrorType implements MirrorType, ErrorTypeModel
  def initialize(messages:List, type:Type, supertype:MirrorType)
    super(messages)
    @supertype = supertype
    @type = type
  end

  def initialize(context:Context, error:ErrorType)
    initialize(
        error.messages,
        Type.getType("Lmirah/lang/errors/UnknownType;"),
        MirrorType(
            context[MirrorTypeSystem].loadNamedType(
                "java.lang.Object").resolve))
  end

  def superclass:JVMType; @supertype; end
  def getAsmType:Type; @type; end
  def flags:int; Opcodes.ACC_PUBLIC; end

  def isPrimitive:boolean; false; end
  def isEnum:boolean; false; end
  def isInterface:boolean; false; end
  def isAbstract:boolean; false; end

  def isAnnotation:boolean; false; end
  def retention:String; nil; end

  def isArray:boolean; false; end
  def getComponentType:JVMType; nil; end

  def hasStaticField(name:String):boolean; false; end

  def interfaces:TypeFuture[]
    TypeFuture[0]
  end

  def getMethod(name:String, params:List):JVMMethod; nil; end

  def getDeclaredFields:JVMMethod[]; JVMMethod[0]; end
  def getAllDeclaredMethods; Collections.emptyList; end
  def getDeclaredField(name:String):JVMMethod; nil; end
  
  def notifyOfIncompatibleChange; end
  def onIncompatibleChange(listener:Runnable):void; end
  def removeChangeListener(listener:Runnable):void; end
  
  def addMethodListener(name:String, listener:MethodListener):void; end
  def invalidateMethod(name:String):void; end
  
  def unmeta; self; end

  def getKind; TypeKind.ERROR; end
  def accept(v, p); v.visitError(self, p); end
  def isSameType(other)
    import static org.mirah.util.Comparisons.*
    areSame(self, other)
  end
  def isSupertypeOf(other)
    true
  end
  def directSupertypes
    if @supertype
      [@supertype]
    else
      Collections.emptyList
    end
  end
  def erasure
    self
  end
end