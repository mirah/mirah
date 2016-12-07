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

import mirah.lang.ast.*
import org.mirah.util.Context
import org.mirah.typer.Typer
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMTypeUtils

# Runs class cleanup on any enclosed classes.
class MethodCleanup < NodeScanner
  def initialize(context: Context, method: MethodDefinition)
    @context = context
    @typer = context[Typer]
    @scope = @typer.scoper.getIntroducedScope(method)
    @method = method
  end

  def clean: void
    scan(@method.body, nil)
  end

  def enterDefault(node, arg)
    false
  end

  def enterClassDefinition(node, arg)
    ClassCleanup.new(@context, node).clean
    false
  end

  def enterClosureDefinition(node, arg)
    if @typer.getResolvedType(node).equals(@scope.binding_type) && node.body_size == 0
      @scope.capturedLocals.each do |name: String|
        type = @scope.getLocalType(name, node.position).resolve.as!(JVMType)

        #type = JVMType(@typer.type_system.getLocalType(@scope, String(name), node.position).resolve)
        if type.kind_of? MirrorType
          type = type.as!(MirrorType).erasure.as!(Object).as!(JVMType)
        end
        typeref = TypeRefImpl.new(type.name, JVMTypeUtils.isArray(type), false, node.position)
        decl = FieldDeclaration.new(SimpleString.new(name), typeref, nil, [
          Annotation.new(SimpleString.new('org.mirah.jvm.types.Modifiers'), [
            HashEntry.new(SimpleString.new('access'), SimpleString.new('PROTECTED')),
            ])
        ])
        node.body.add(decl)
        @typer.infer(decl)
      end
    end
    enterClassDefinition(node, arg)
    false
  end

  def enterInterfaceDeclaration(node, arg)
    enterClassDefinition(node, arg)
    false
  end

  def enterNodeList(node, arg)
    # Scan the children
    true
  end
end
