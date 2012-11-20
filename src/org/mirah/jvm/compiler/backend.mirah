package org.mirah.jvm.compiler

import mirah.lang.ast.Script
import org.mirah.typer.Typer

interface BytecodeConsumer
  def consumeClass(filename:String, bytecode:byte[]):void; end
end

class Backend
  def initialize(typer:Typer)
    @context = Context.new
    @context[Typer] = typer
    @context[DiagnosticListener] = SimpleDiagnostics.new
    @context[Compiler] = typer.macro_compiler
    @cleanup = ScriptCleanup.new
    @compiler = ScriptCompiler.new
  end
  
  def visit(script:Script, arg:Object)
    
  end
  
  def generate(consumer:BytecodeConsumer)
    @compiler.generate(consumer)
  end
end