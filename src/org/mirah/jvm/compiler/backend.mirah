# Copyright (c) 2015 The Mirah project authors. All Rights Reserved.
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

import java.util.Map

import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream

import javax.tools.DiagnosticListener
import mirah.lang.ast.Script
import org.mirah.typer.Typer
import org.mirah.util.Context
import org.mirah.util.SimpleDiagnostics
import org.mirah.macros.Compiler

interface BytecodeConsumer
  def consumeClass(filename:String, bytecode:byte[]):void; end
end

class Backend
  def initialize(context:Context)
    @context = context
    @diagnostics = context[SimpleDiagnostics]
    @context[Compiler] = @context[Typer].macro_compiler
    @context[AnnotationCompiler] = AnnotationCompiler.new(@context)
    @compiler = ScriptCompiler.new(@context)
    unless @context[JvmVersion]
      @context[JvmVersion] = JvmVersion.new
    end
  end

  def initialize(typer:Typer)
    @context = Context.new
    @context[Typer] = typer
    @diagnostics = SimpleDiagnostics.new(true)
    @context[DiagnosticListener] = @diagnostics
    @context[Compiler] = typer.macro_compiler
    @context[AnnotationCompiler] = AnnotationCompiler.new(@context)
    @compiler = ScriptCompiler.new(@context)
  end

  def visit(script:Script, arg:Object):void
    clean(script, arg)
    compile(script, arg)
  end

  def clean(script:Script, arg:Object):void
    script.accept(ProxyCleanup.new, arg)
    script.accept(ScriptCleanup.new(@context), arg)
  end

  def compile(script:Script, arg:Object):void
    script.accept(@compiler, arg)
  end

  def generate(consumer:BytecodeConsumer)
    raise UnsupportedOperationException, "Compilation failed" if @diagnostics.errorCount > 0
    @compiler.generate(consumer)
  end


  def self.write_out_file(macro_backend: Backend, class_map: Map, destination: String): String
    first_class_name = nil
    macro_backend.generate do |filename, bytes|
      classname = filename.replace(?/, ?.)
      first_class_name ||= classname if classname.contains('$Extension')
      class_map[classname] = bytes

      file = File.new(destination, "#{filename.replace(?., ?/)}.class")
      parent = file.getParentFile
      parent.mkdirs if parent

      output = BufferedOutputStream.new(FileOutputStream.new(file))
      output.write(bytes)
      output.close
    end
    first_class_name
  end
end