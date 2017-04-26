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

package org.mirah.tool

import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.URL
import java.net.URLClassLoader
import java.util.HashSet
import java.util.List
import org.mirah.util.Logger
import java.util.logging.Level
import java.util.regex.Pattern
import java.util.Collections
import java.util.Map
import java.util.HashMap
import javax.tools.Diagnostic.Kind
import javax.tools.DiagnosticListener
import mirah.impl.MirahParser
import mirah.lang.ast.Package as MirahPackage
import mirah.lang.ast.*
import org.mirah.IsolatedResourceLoader
import org.mirah.MirahClassLoader
import org.mirah.MirahLogFormatter
import org.mirah.jvm.compiler.Backend
import org.mirah.jvm.compiler.ExtensionCleanup
import org.mirah.jvm.compiler.BytecodeConsumer
import org.mirah.jvm.compiler.JvmVersion
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.jvm.mirrors.BetterScopeFactory
import org.mirah.jvm.mirrors.MirrorScope
import org.mirah.jvm.mirrors.ClassResourceLoader
import org.mirah.jvm.mirrors.ClassLoaderResourceLoader
import org.mirah.jvm.mirrors.FilteredResources
import org.mirah.jvm.mirrors.NegativeFilteredResources
import org.mirah.jvm.mirrors.SafeTyper
import org.mirah.jvm.mirrors.debug.DebuggerInterface
import org.mirah.jvm.mirrors.debug.DebugTyper
import org.mirah.macros.JvmBackend
import org.mirah.mmeta.BaseParser
import org.mirah.typer.simple.SimpleScoper
import org.mirah.typer.Scoper
import org.mirah.typer.Typer
import org.mirah.typer.TypeSystem
import org.mirah.util.ParserDiagnostics
import org.mirah.util.SimpleDiagnostics
import org.mirah.util.AstFormatter
import org.mirah.util.TooManyErrorsException
import org.mirah.util.LazyTypePrinter
import org.mirah.util.Context
import org.mirah.util.OptionParser
import org.mirah.util.AstChecker

class CompilationFailure < Exception
end

class MirahCompiler implements JvmBackend

  def initialize(
      diagnostics: SimpleDiagnostics, jvm: JvmVersion, classpath: URL[],
      bootclasspath: URL[], macroclasspath: URL[], destination: String,
      macro_destination: String,
      debugger: DebuggerInterface=nil)
    @diagnostics = diagnostics
    @jvm = jvm
    @destination = destination
    @macro_destination = macro_destination
    @debugger = debugger

    @context          = context = Context.new
    context[JvmBackend]         = self
    context[DiagnosticListener] = @diagnostics
    context[SimpleDiagnostics]  = @diagnostics
    context[JvmVersion]         = @jvm
    context[DebuggerInterface]  = debugger

    @macro_context                     = Context.new
    @macro_context[JvmBackend]         = self
    @macro_context[DiagnosticListener] = @diagnostics
    @macro_context[SimpleDiagnostics]  = @diagnostics
    @macro_context[JvmVersion]         = @jvm
    @macro_context[DebuggerInterface]  = debugger

    # The main type system needs access to the macro one to call macros.
    @context[Context] = @macro_context

    createTypeSystems(classpath, bootclasspath, macroclasspath)

    # TODO allow this. ambiguous for parser?
    #context[Scoper] = @scoper = SimpleScoper.new BetterScopeFactory.new
    context[Scoper] = @scoper = SimpleScoper.new(BetterScopeFactory.new)

    context[MirahParser] = @parser = MirahParser.new
    # BaseParser(@parser).diagnostics = ParserDiagnostics.new(@diagnostics) # Field "diagnostics" does not seem to exist in the current mirah/mmeta source code, but it did exist in an ancient mmeta.jar. 

    @macro_context[Scoper] = @scoper
    @macro_context[MirahParser] = @parser
    @macro_context[Typer] = @macro_typer = createTyper(
        debugger, @macro_context, @macro_types, @scoper, self, @parser)

    context[Typer] = @typer = createTyper(
        debugger, context, @types, @scoper, self, @parser)

    # Make sure macros are compiled using the correct type system.
    @typer.macro_compiler = @macro_typer.macro_compiler

    # Ugh -- we have to use separate type systems for compiling and loading
    # macros.
    @typer.macro_compiler.setMacroLoader(@typer)

    @backend = Backend.new(context)
    @macro_backend = Backend.new(@macro_context)
    @asts = []
  end

  def self.initialize:void
    @@log = Logger.getLogger(Mirahc.class.getName)
  end

  def getParsedNodes
    @asts
  end

  def createTyper(debugger:DebuggerInterface, context:Context, types:TypeSystem,
                  scopes:Scoper, jvm_backend:JvmBackend, parser:MirahParser)
    if debugger.nil?
      SafeTyper.new(context, types, scopes, jvm_backend, parser)
    else
      DebugTyper.new(debugger, context, types, scopes, jvm_backend, parser)
    end
  end

  def parse(code:CodeSource)
    begin
      node = @parser.parse(code).as!(Node)
    rescue org.mirah.mmeta.SyntaxError => e
      raise Exception.new("#{code.name} failed to parse.",e)
    end
    if node.nil?
      puts "#{code.name} failed to parse."
    else
      @asts.add(node)
      if @debugger
        @debugger.parsedNode(node)
      end
    end
    failIfErrors
    node
  end

  def infer
    sorted_asts = @asts # ImportSorter.new.sort(@asts)

    sorted_asts.each do |node: Node|
      begin
        AstChecker.maybe_check(node) 
        @typer.infer(node, false)
        AstChecker.maybe_check(node)
      ensure
        logAst(node, @typer)
      end
    end

    @typer.finish_closures

    sorted_asts.each do |node: Node|
      processInferenceErrors(node, @context)
    end
    failIfErrors
  end

  def processInferenceErrors(node:Node, context:Context):void
    errors = ErrorCollector.new(context)
    errors.scan(node, nil)
  end

  def logAst(node:Node, typer:Typer):void
    @@log.log(Level.FINE, "Inferred types:\n{0}", LazyTypePrinter.new(typer, node))
  end

  def logExtensionAst(ast)
    @@log.log(Level.FINE, "Inferred types:\n{0}", AstFormatter.new(ast))
  end

  def failIfErrors
    if @diagnostics.errorCount > 0
      raise CompilationFailure.new
    end
  end

  def compileAndLoadExtension(ast)
    logAst(ast, @macro_typer)
    processInferenceErrors(ast, @macro_context)
    failIfErrors

    @macro_backend.clean(ast, nil)
    processInferenceErrors(ast, @macro_context)
    failIfErrors

    @macro_backend.compile(ast, nil)

    class_name = Backend.write_out_file(
      @macro_backend, @extension_classes, @macro_destination)

    @extension_loader.loadClass(class_name)
  end

  def compile(generator: BytecodeConsumer)
    @asts.each do |node: Script|
      @backend.clean(node, nil)
      node.accept(ExtensionCleanup.new(@macro_backend,
                 @extension_classes,
                 @macro_destination,
                 @macro_typer),
                HashMap.new)

      processInferenceErrors(node, @context)
    end

    failIfErrors()

    @asts.each do |node: Script|
      @backend.compile(node, nil)
    end
    @backend.generate(generator)
  end

  def createTypeSystems(classpath: URL[], bootcp: URL[], macrocp: URL[]): void
    # Now one for macros: These will be loaded into this JVM,
    # so we don't support bootclasspath.
    macrocp ||= classpath

    macro_class_loader = createMacroClassLoader macrocp
    @context[ClassLoader] = macro_class_loader
    @macro_context[ClassLoader] = macro_class_loader

    @extension_classes = {}
    @extension_loader = createExtensionClassLoader macrocp, @extension_classes

    macroloader = createMacroLoader(macrocp)
    @macro_context[TypeSystem] = @macro_types = MirrorTypeSystem.new(
        @macro_context, macroloader)

    # Construct a loader with the standard Java classes plus the classpath
    classloader = createClassLoader classpath, bootcp
    @context[TypeSystem] = @types = MirrorTypeSystem.new(
        @context, classloader)
  end

  def createBootLoader(bootcp: URL[])
    # Construct a loader with the standard Java classes plus the classpath
    bootloader = if bootcp
      ClassLoaderResourceLoader.new(IsolatedResourceLoader.new(bootcp))
    else
      # Make sure our internal classes don't sneak in here
      NegativeFilteredResources.new(
          ClassResourceLoader.new(System.class),
          Pattern.compile("^/?(mirah/|org/mirah|org/jruby)"))
    end
    # Annotations used by the compiler also need to be loadable
    FilteredResources.new(
        ClassResourceLoader.new(Mirahc.class),
        Pattern.compile("^/?org/mirah/jvm/(types/(Flags|Member|Modifiers))|compiler/Cleaned"), bootloader)
  end

  def createExtensionClassLoader(macrocp: URL[], extension_class_map: Map): MirahClassLoader
    extension_parent = URLClassLoader.new(macrocp, Mirahc.class.getClassLoader())
    MirahClassLoader.new(extension_parent, extension_class_map)
  end

  def createMacroClassLoader(macrocp: URL[]): ClassLoader
    URLClassLoader.new(macrocp, MirahCompiler.class.getClassLoader())
  end

  def createClassLoader(classpath: URL[], bootcp: URL[])
    bootloader = createBootLoader(bootcp)

    ClassLoaderResourceLoader.new(IsolatedResourceLoader.new(classpath), bootloader)
  end

  def createMacroLoader(macrocp: URL[])
    bootloader = ClassResourceLoader.new(System.class)
    ClassLoaderResourceLoader.new(
        IsolatedResourceLoader.new(macrocp),
        FilteredResources.new(
            ClassResourceLoader.new(Mirahc.class),
            Pattern.compile("^/?(mirah/|org/mirah)"),
            bootloader))
  end
end