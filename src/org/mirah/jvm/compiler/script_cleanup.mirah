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
import org.mirah.util.AstFormatter
import org.mirah.util.Context
import java.util.logging.Level
import java.util.logging.Logger

import java.util.ArrayList

# Moves top-level nodes into the appropriate class/method.
# For example, if foo.mirah contained this:
#     def bar:void; end
#     puts :hi
# ScriptCleanup transforms it to this:
#    class Foo
#      class << self
#        def bar:void; end
#      end
#      def self.main(ARGV:String[])
#        puts :hi
#      end
#    end
class ScriptCleanup < NodeScanner
  def self.initialize:void
    @@log = Logger.getLogger(ScriptCleanup.class.getName)
  end
  
  def initialize(context:Context)
    @context = context
    @typer = context[Typer]
    @parser = context[MacroCompiler]
    @main_code = ArrayList.new
    @methods = ArrayList.new
    @classes = {}
  end
  def enterScript(node, arg)
    @@log.log(Level.FINER, "Before cleanup:\n{0}", AstFormatter.new(node))
    true
  end
  def exitScript(script, arg)
    unless @main_code.isEmpty && @methods.isEmpty
      klass = getOrCreateClass(script)
      unless @main_code.isEmpty
        main = @parser.quote { def self.main(ARGV:String[]):void; end }
        @main_code.each do |n|
          node = Node(n)
          node.parent.removeChild(node)
          node.setParent(nil)  # TODO: ast bug
          main.body.add(node)
        end
        klass.body.add(main)
        @typer.scoper.copyScopeFrom(script, main)
        @typer.infer(main, false)
      end
      unless @methods.isEmpty
        nodes = @parser.quote { class << self; end }
        @methods.each do |n|
          mdef = MethodDefinition(n)
          MethodCleanup.new(@context, mdef).clean
          mdef.parent.removeChild(mdef)
          mdef.setParent(nil)  # TODO: ast bug
          nodes.body.add(mdef)
        end
        klass.body.add(nodes)
        @typer.infer(nodes, false)
      end
      if @generatedClass
        ClassCleanup.new(@context, klass).clean
      end
    end
    @@log.log(Level.FINE, "After cleanup:\n{0}", AstFormatter.new(script))
    script
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
    ClassCleanup.new(@context, node).clean
    false
  end
  def enterClosureDefinition(node, arg)
    @main_code.add(node)
    ClassCleanup.new(@context, node).clean
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
          def initialize;super; end
        end
      end
      klass.position = script.position
      script.body.insert(0, klass)
      @typer.infer(klass, false)
      @generatedClass = true
    end
    ClassDefinition(klass)
  end
end