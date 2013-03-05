package org.mirah.jvm.compiler

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
  def initialize(typer:Typer)
    @context = Context.new
    @context[Typer] = typer
    @diagnostics = SimpleDiagnostics.new(true)
    @context[DiagnosticListener] = @diagnostics
    @context[Compiler] = typer.macro_compiler
    @context[AnnotationCompiler] = AnnotationCompiler.new(@context)
    @cleanup = ScriptCleanup.new(@context)
    @compiler = ScriptCompiler.new(@context)
  end
  
  def visit(script:Script, arg:Object):void
    script.accept(@cleanup, arg)
    script.accept(@compiler, arg)
  end
  
  def generate(consumer:BytecodeConsumer)
    raise UnsupportedOperationException, "Compilation failed" if @diagnostics.errorCount > 0
    @compiler.generate(consumer)
  end
end