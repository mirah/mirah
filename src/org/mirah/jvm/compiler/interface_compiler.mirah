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

package org.mirah.jvm.compiler

import org.jruby.org.objectweb.asm.Opcodes
import mirah.lang.ast.ClassDefinition
import mirah.lang.ast.InterfaceDeclaration
import mirah.lang.ast.MethodDefinition
import org.mirah.util.Context

class InterfaceCompiler < ClassCompiler
  def initialize(context:Context, classdef:InterfaceDeclaration)
    super(context, ClassDefinition(classdef))
  end
  
  def flags
    Opcodes.ACC_PUBLIC | Opcodes.ACC_ABSTRACT | Opcodes.ACC_INTERFACE
  end
  
  def methodFlags(mdef:MethodDefinition, isStatic:boolean)
    if isStatic
      super
    else
      super | Opcodes.ACC_ABSTRACT
    end
  end
end