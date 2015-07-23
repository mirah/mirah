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

import java.util.LinkedList
import org.mirah.util.Logger
import org.mirah.typer.Typer
import org.mirah.typer.simple.TypePrinter
import org.mirah.util.Context

class ScriptCompiler < BaseCompiler
  def self.initialize:void
    @@log = Logger.getLogger(ScriptCompiler.class.getName)
  end
  def initialize(context:Context)
    super(context)
    @typer = context[Typer]
    @classes = LinkedList.new
  end
  
  def visitScript(script, expression)
    visit(script.body, expression)
  rescue Exception => ex
    #TypePrinter.new(@typer, System.out).scan(script, nil)

    buf = java::io::ByteArrayOutputStream.new
    ps = java::io::PrintStream.new(buf)
    printer = TypePrinter.new(@typer, ps)
    printer.scan(script, nil)
    ps.close()
    @@log.fine("Inferred types for expression with errors:\n#{String.new(buf.toByteArray)}")

    raise ex
  end
    
  def visitClassDefinition(class_def, expression)
    compiler = ClassCompiler.new(self.context, class_def)
    @classes.add(compiler)
    compiler.compile
  end
  
  def visitInterfaceDeclaration(class_def, expression)
    compiler = InterfaceCompiler.new(self.context, class_def)
    @classes.add(compiler)
    compiler.compile
  end
  
  def generate(consumer:BytecodeConsumer)
    until @classes.isEmpty
      compiler = ClassCompiler(@classes.removeFirst)
      consumer.consumeClass(compiler.internal_name, compiler.getBytes)
      @classes.addAll(compiler.innerClasses)
    end
  end
end