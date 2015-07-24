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

import org.mirah.util.Logger
import org.objectweb.asm.Type
import org.objectweb.asm.commons.Method

import mirah.lang.ast.Hash
import org.mirah.jvm.types.MemberKind

class HashCompiler < BaseCompiler
  def self.initialize:void
    @@log = Logger.getLogger(HashCompiler.class.getName)
  end
  def initialize(method:BaseCompiler, bytecode:Bytecode)
    super(method.context)
    @method = method
    @bytecode = bytecode
    @object = findType("java.lang.Object")
    @map = findType("java.util.Map")
    @hashmap = findType("java.util.HashMap")
    
    arg = Type[1]
    arg[0] = Type.getType("I")
    @constructor = Method.new("<init>", Type.getType("V"), arg)

    args = Type[2]
    args[0] = args[1] = @object.getAsmType
    @put = Method.new("put", @object.getAsmType, args)
  end
  
  def compile(hash:Hash):void
    @bytecode.recordPosition(hash.position)
    @bytecode.newInstance(@hashmap.getAsmType)
    @bytecode.dup
    @bytecode.push(Math.max(int(hash.size / 0.75), 16))
    @bytecode.invokeConstructor(@hashmap.getAsmType, @constructor)
    hash.size.times do |i|
      @bytecode.dup
      entry = hash.get(i)
      @method.visit(entry.key, Boolean.TRUE)
      @method.visit(entry.value, Boolean.TRUE)
      @bytecode.convertValue(getInferredType(entry.value), @object)
      @bytecode.invokeInterface(@map.getAsmType, @put)
      @bytecode.pop
    end
  end
end