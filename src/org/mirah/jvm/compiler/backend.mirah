package org.mirah.jvm.compiler

import javax.tools.DiagnosticListener
import mirah.lang.ast.Script
import org.mirah.typer.Typer
import org.mirah.util.Context
import org.mirah.util.SimpleDiagnostics

interface BytecodeConsumer
  def consumeClass(filename:String, bytecode:byte[]):void; end
end

class Backend
  def initialize(typer:Typer)
    @context = Context.new
    @context[Typer] = typer
    @context[DiagnosticListener] = SimpleDiagnostics.new(true)
    @context[Compiler] = typer.macro_compiler
    @cleanup = ScriptCleanup.new(@context)
    @compiler = ScriptCompiler.new(@context)
  end
  
  def visit(script:Script, arg:Object)
    
  end
  
  def generate(consumer:BytecodeConsumer)
    @compiler.generate(consumer)
  end
end