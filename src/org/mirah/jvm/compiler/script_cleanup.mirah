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
import org.mirah.typer.Typer
import org.mirah.macros.Compiler as MacroCompiler
import org.mirah.util.Context

import java.util.ArrayList

# Moves top-level nodes into the appropriate class/method.
class ScriptCleanup < NodeScanner
  def initialize(context:Context)
    @context = context
    @typer = context[Typer]
    @parser = context[MacroCompiler]
    @main_code = ArrayList.new
    @methods = ArrayList.new
    @classes = {}
  end
  def enterScript(node, arg)
    true
  end
  def exitScript(script, arg)
    if @main_code.isEmpty && @methods.isEmpty
      return script
    end
    klass = getOrCreateClass(script)
    unless @main_code.isEmpty
      main = @parser.quote { def self.main(ARGV:String[]); end }
      @main_code.each do |n|
        node = Node(n)
        node.parent.removeChild(node)
        main.body.add(node)
      end
      @typer.infer(main, false)
      klass.body.add(main)
    end
    unless @methods.isEmpty
      nodes = @parser.quote { class << self; end }
      @methods.each do |n|
        node = Node(n)
        node.parent.removeChild(node)
        nodes.body.add(node)
      end
      @typer.infer(nodes, false)
      klass.body.add(nodes)
    end
  end
  def enterDefault(node, arg)
    @main_code.add(node)
    false
  end
  def enterMethodDefinition(node, arg)
    @methods.add(node)
    false
  end
  def enterStaticMethodDefinition(node, arg)
    @methods.add(node)
    false
  end
  def enterConstructorDefinition(node, arg)
    @methods.add(node)
    false
  end
  def enterPackage(node, arg)
    # ignore
    false
  end
  def enterClassDefinition(node, arg)
    type = @typer.infer(node).resolve
    @classes[type] = node
    ClassCleanup.new(@context, node).scan(node.body, arg)
    false
  end
  def enterInterfaceDeclaration(node, arg)
    enterClassDefinition(node, arg)
    false
  end
  def enterImport(node, arg)
    # ignore
    false
  end
  def enterNodeList(node, arg)
    # Scan the children
    true
  end
  
  def getOrCreateClass(script:Script)
    scope = @typer.scoper.getIntroducedScope(script)
    type = @typer.type_system.getMainType(scope, script).resolve
    klass = ClassDefinition(@classes[type])
    if klass.nil?
      klass = @parser.quote do
        class `type.name`
          def initialize; end
        end
      end
      klass.position = script.position
    end
    ClassDefinition(klass)
  end
end