# Copyright (c) 2013 The Mirah project authors. All Rights Reserved.
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
import java.util.logging.Logger
import java.util.logging.Level
import java.util.regex.Pattern
import javax.tools.Diagnostic.Kind
import javax.tools.DiagnosticListener
import mirah.impl.MirahParser
import mirah.lang.ast.CodeSource
import mirah.lang.ast.Node
import mirah.lang.ast.Script
import mirah.lang.ast.StreamCodeSource
import mirah.lang.ast.StringCodeSource
import org.mirah.IsolatedResourceLoader
import org.mirah.MirahClassLoader
import org.mirah.MirahLogFormatter
import org.mirah.jvm.compiler.Backend
import org.mirah.jvm.compiler.BytecodeConsumer
import org.mirah.jvm.compiler.JvmVersion
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.jvm.mirrors.JVMScope
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

class CompilationFailure < Exception
end

class MirahCompiler implements JvmBackend
  @@VERSION = "0.1.2.dev"

  def initialize(
      diagnostics:SimpleDiagnostics, jvm:JvmVersion, classpath:URL[],
      bootclasspath:URL[], macroclasspath:URL[], macro_destination:String,
      debugger:DebuggerInterface=nil)
    @diagnostics = diagnostics
    @jvm = jvm
    @destination = macro_destination
    @debugger = debugger

    @context = context = Context.new
    context[JvmBackend] = self
    context[DiagnosticListener] = @diagnostics
    context[SimpleDiagnostics] = @diagnostics
    context[JvmVersion] = @jvm
    context[DebuggerInterface] = debugger

    @macro_context = Context.new
    @macro_context[JvmBackend] = self
    @macro_context[DiagnosticListener] = @diagnostics
    @macro_context[SimpleDiagnostics] = @diagnostics
    @macro_context[JvmVersion] = @jvm
    @macro_context[DebuggerInterface] = debugger

    # The main type system needs access to the macro one to call macros.
    @context[Context] = @macro_context

    createTypeSystems(classpath, bootclasspath, macroclasspath)
    context[Scoper] = @scoper = SimpleScoper.new do |s, node|
      scope = JVMScope.new(s)
      scope.context = node
      scope
    end
    context[MirahParser] = @parser = MirahParser.new
    BaseParser(@parser).diagnostics = ParserDiagnostics.new(@diagnostics)

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

  def createTyper(debugger:DebuggerInterface, context:Context, types:TypeSystem,
                  scopes:Scoper, jvm_backend:JvmBackend, parser:MirahParser)
    if debugger.nil?
      SafeTyper.new(context, types, scopes, jvm_backend, parser)
    else
      DebugTyper.new(debugger, context, types, scopes, jvm_backend, parser)
    end
  end

  def parse(code:CodeSource)
    node = Node(@parser.parse(code))
    if node.nil?
      puts "#{code.name} parsed to nil"
    else
      @asts.add(node)
      if @debugger
        @debugger.parsedNode(node)
      end
    end
    if @diagnostics.errorCount > 0
      raise CompilationFailure.new
    end
    node
  end

  def infer
    @asts.each do |node:Node|
      begin
        @typer.infer(node, false)
      ensure
        logAst(node, @typer)
      end
    end
    @asts.each do |node:Node|
      processInferenceErrors(node, @context)
    end
    if @diagnostics.errorCount > 0
      raise CompilationFailure.new
    end
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

  def compileAndLoadExtension(ast)
    logAst(ast, @macro_typer)
    processInferenceErrors(ast, @macro_context)
    if @diagnostics.errorCount > 0
      raise CompilationFailure.new
    end
    @macro_backend.clean(ast, nil)
    processInferenceErrors(ast, @macro_context)
    if @diagnostics.errorCount > 0
      raise CompilationFailure.new
    end
    @macro_backend.compile(ast, nil)
    first_class_name = nil
    destination = @destination
    class_map = @extension_classes
    @macro_backend.generate do |filename, bytes|
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
    @extension_loader.loadClass(first_class_name)
  end

  def compile(generator:BytecodeConsumer)
    @asts.each do |n|
      node = Script(n)
      @backend.clean(node, nil)
      processInferenceErrors(node, @context)
      if @diagnostics.errorCount > 0
        raise CompilationFailure.new
      end
      @backend.compile(node, nil)
    end
    @backend.generate(generator)
  end

  def createTypeSystems(classpath:URL[], bootcp:URL[], macrocp:URL[]):void
    # Construct a loader with the standard Java classes plus the classpath
    bootloader = if bootcp
      ClassLoaderResourceLoader.new(IsolatedResourceLoader.new(bootcp))
    else
      # Make sure our internal classes don't sneak in here
      NegativeFilteredResources.new(
          ClassResourceLoader.new(System.class),
          Pattern.compile("^/?(mirah/|org/mirah|org/jruby)"))
    end
    classloader = ClassLoaderResourceLoader.new(
        IsolatedResourceLoader.new(classpath), bootloader)
    
    # Now one for macros: These will be loaded into this JVM,
    # so we don't support bootclasspath.
    macrocp ||= classpath
    bootloader = ClassResourceLoader.new(System.class)
    macroloader = ClassLoaderResourceLoader.new(
        IsolatedResourceLoader.new(macrocp),
        FilteredResources.new(
            ClassResourceLoader.new(Mirahc.class),
            Pattern.compile("^/?(mirah/|org/mirah)"),
            bootloader))

    macro_class_loader = URLClassLoader.new(
        macrocp, MirahCompiler.class.getClassLoader())
    @context[ClassLoader] = macro_class_loader
    @macro_context[ClassLoader] = macro_class_loader
        
    @extension_classes = {}
    extension_parent = URLClassLoader.new(
       macrocp, Mirahc.class.getClassLoader())
    @extension_loader = MirahClassLoader.new(
       extension_parent, @extension_classes)
    
    @macro_context[TypeSystem] = @macro_types = MirrorTypeSystem.new(
        @macro_context, macroloader)
    @context[TypeSystem] = @types = MirrorTypeSystem.new(
        @context, classloader)
  end
end