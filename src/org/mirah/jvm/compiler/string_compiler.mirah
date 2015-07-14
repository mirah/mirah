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
import mirah.lang.ast.StringPieceList

class StringCompiler < BaseCompiler
  def self.initialize:void
    @@log = Logger.getLogger(StringCompiler.class.getName)
  end

  def initialize(method: MethodCompiler)
    super(method.context)
    @sb = findType('java.lang.StringBuilder')
    @method = method
    @bytecode = method.bytecode
  end
  
  def defaultNode(node, expression)
    @method.compile(node)
    type = getInferredType(node)
    method = @sb.getMethod("append", [type])
    @bytecode.invokeVirtual(@sb.getAsmType, methodDescriptor(method))
  end
  
  def compile(node: StringPieceList, expression: boolean): void
    sb = @sb.getAsmType
    @bytecode.newInstance(sb)
    @bytecode.dup
    @bytecode.invokeConstructor(sb, Method.new("<init>", Type.getType("V"), Type[0]))
    visitStringPieceList(node, Boolean.TRUE)
    @bytecode.invokeVirtual(sb, methodDescriptor("toString", findType("java.lang.String"), []))
    @bytecode.pop unless expression
  end
  
  def visitStringConcat(node, expression)
    visitStringPieceList(node.strings, expression)
  end
  
  def visitStringPieceList(node, expression)
    node.size.times do |i|
      node.get(i).accept(self, expression)
    end
  end
  
  def visitStringEval(node, expression)
    defaultNode(node.value, expression)
  end
end