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

import java.util.Collections
import java.util.List
import org.mirah.typer.ErrorType
import org.mirah.typer.TypeFuture
import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.Type
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMMethod

class JvmErrorType < ErrorType implements MirrorType
  def initialize(message:List, type:Type)
    super(message)
    @type = type
  end

  def superclass:JVMType; nil; end
  def internal_name:String; @type.getInternalName; end
  def class_id:String; @type.getDescriptor; end
  def getAsmType:Type; @type; end
  def flags:int; Opcodes.ACC_PUBLIC; end

  def isPrimitive:boolean; false; end
  def isEnum:boolean; false; end
  def isInterface:boolean; false; end

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
end