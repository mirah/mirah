# Copyright (c) 2012-2014 The Mirah project authors. All Rights Reserved.
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

import org.mirah.util.Logger
import mirah.lang.ast.Array
import org.mirah.jvm.types.MemberKind
import org.objectweb.asm.commons.Method
import org.objectweb.asm.Type

class ArrayCompiler < BaseCompiler
  def self.initialize: void
    @@log = Logger.getLogger(ArrayCompiler.class.getName)
  end

  def initialize(method: BaseCompiler, bytecode: Bytecode)
    super(method.context)
    @method = method
    @bytecode = bytecode
    @object = findType("java.lang.Object")
    @list = findType("java.util.List")
    @arraylist = findType("java.util.ArrayList")
    
    arg = Type[1]
    arg[0] = Type.getType("I")
    @constructor = Method.new("<init>", Type.getType("V"), arg)
    arg[0] = @object.getAsmType
    @add = Method.new("add", Type.getType("Z"), arg)
  end
  
  def compile(array: Array): void
    @bytecode.recordPosition(array.position)
    @bytecode.newInstance(@arraylist.getAsmType)
    @bytecode.dup
    @bytecode.push(array.values_size)
    @bytecode.invokeConstructor(@arraylist.getAsmType, @constructor)

    array.values_size.times do |i|
      @bytecode.dup
      value = array.values(i)
      @method.visit(value, Boolean.TRUE)
      @bytecode.convertValue(getInferredType(value), @object)
      @bytecode.invokeInterface(@list.getAsmType, @add)
      @bytecode.pop
    end
  end
end