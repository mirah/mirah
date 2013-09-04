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
import java.util.List
import java.util.logging.Logger
import java.util.logging.Level
import java.util.regex.Pattern
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
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.jvm.mirrors.JVMScope
import org.mirah.jvm.mirrors.ClassResourceLoader
import org.mirah.jvm.mirrors.ClassLoaderResourceLoader
import org.mirah.jvm.mirrors.FilteredResources
import org.mirah.jvm.mirrors.SafeTyper
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

class Mirahc implements JvmBackend
  @@VERSION = "0.1.2.dev"

  def initialize(args:String[])
    @logger = MirahLogFormatter.new(true).install
    @code_sources = []
    @destination = "."
    @diagnostics = SimpleDiagnostics.new(true)
    processArgs(args)
    @context = context = Context.new
    context[JvmBackend] = self
    context[DiagnosticListener] = @diagnostics
    context[SimpleDiagnostics] = @diagnostics

    @macro_context = Context.new
    @macro_context[JvmBackend] = self
    @macro_context[DiagnosticListener] = @diagnostics
    @macro_context[SimpleDiagnostics] = @diagnostics

    createTypeSystems
    context[Scoper] = @scoper = SimpleScoper.new do |s, node|
      scope = JVMScope.new(s)
      scope.context = node
      scope
    end
    context[MirahParser] = @parser = MirahParser.new
    BaseParser(@parser).diagnostics = ParserDiagnostics.new(@diagnostics)

    @macro_context[Scoper] = @scoper
    @macro_context[MirahParser] = @parser
    @macro_context[Typer] = @macro_typer = SafeTyper.new(
        @macro_context, @macro_types, @scoper, self, @parser)

    context[Typer] = @typer = SafeTyper.new(
        context, @types, @scoper, self, @parser)

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

  def parse(code:CodeSource)
    node = @parser.parse(code)
    if node.nil?
      puts "#{code.name} parsed to nil"
    else
      @asts.add(node)
    end
    if @diagnostics.errorCount > 0
      puts "#{@diagnostics.errorCount} errors"
      System.exit(1)
    end
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
      puts "#{@diagnostics.errorCount} errors"
      System.exit(1)
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
      puts "#{@diagnostics.errorCount} errors"
      System.exit(1)
    end
    @macro_backend.clean(ast, nil)
    processInferenceErrors(ast, @macro_context)
    if @diagnostics.errorCount > 0
      puts "#{@diagnostics.errorCount} errors"
      System.exit(1)
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


  def compile
    @asts.each do |n|
      node = Script(n)
      @backend.clean(node, nil)
      processInferenceErrors(node, @context)
      if @diagnostics.errorCount > 0
        puts "#{@diagnostics.errorCount} errors"
        System.exit(1)
      end
      @backend.compile(node, nil)
    end
    destination = @destination
    @backend.generate do |filename, bytes|
      file = File.new(destination, "#{filename.replace(?., ?/)}.class")
      parent = file.getParentFile
      parent.mkdirs if parent
      output = BufferedOutputStream.new(FileOutputStream.new(file))
      output.write(bytes)
      output.close
    end
  end

  def parseClassPath(classpath:String)
    filenames = classpath.split(File.pathSeparator)
    urls = URL[filenames.length]
    filenames.length.times do |i|
      urls[i] = File.new(filenames[i]).toURI.toURL
    end
    urls
  end

  def setDestination(dest:String):void
    @destination = dest
  end

  def setClasspath(classpath:String):void
    @classpath = parseClassPath(classpath)
  end

  def setBootClasspath(classpath:String):void
    @bootcp = parseClassPath(classpath)
  end

  def setMacroClasspath(classpath:String):void
    @macrocp = parseClassPath(classpath)
  end

  def setMaxErrors(count:int):void
    @diagnostics.setMaxErrors(count)
  end

  def createTypeSystems
    # Construct a loader with the standard Java classes plus the classpath
    bootloader = if @bootcp
      ClassLoaderResourceLoader.new(IsolatedResourceLoader.new(@bootcp))
    else
      ClassResourceLoader.new(System.class)
    end
    @classpath ||= parseClassPath(@destination)
    classloader = ClassLoaderResourceLoader.new(
        IsolatedResourceLoader.new(@classpath), bootloader)
    
    # Now one for macros: These will be loaded into this JVM,
    # so we don't support bootclasspath.
    @macrocp ||= @classpath
    bootloader = ClassResourceLoader.new(System.class)
    macroloader = ClassLoaderResourceLoader.new(
        IsolatedResourceLoader.new(@macrocp),
        FilteredResources.new(
            ClassResourceLoader.new(Mirahc.class),
            Pattern.compile("^(mirah\\.|org\\.mirah\\.macros)"),
            bootloader))
    
    @extension_classes = {}
    extension_parent = URLClassLoader.new(
       @macrocp, Mirahc.class.getClassLoader())
    @extension_loader = MirahClassLoader.new(
       extension_parent, @extension_classes)
    
    @macro_context[TypeSystem] = @macro_types = MirrorTypeSystem.new(
        @macro_context, macroloader)
    @context[TypeSystem] = @types = MirrorTypeSystem.new(
        @context, classloader, macroloader)
  end

  def processArgs(args:String[]):void
    parser = OptionParser.new("Mirahc [flags] <files or -e SCRIPT>")
    parser.addFlag(["h", "help"], "Print this help message.") do
      parser.printUsage
      System.exit(0)
    end
    mirahc = self
    code_sources = @code_sources
    parser.addFlag(
        ["e"], "CODE",
        "Compile an inline script.\n\t(The class will be named DashE)") do |c|
      code_sources.add(StringCodeSource.new('DashE', c))
    end
    version = @@VERSION
    parser.addFlag(['v', 'version'], 'Print the version.') do
      puts "Mirahc v#{version}"
      System.exit(1)
    end
    logger = @logger
    parser.addFlag(['V', 'verbose'], 'Verbose logging.') do
      logger.setLevel(Level.FINE)
    end
    parser.addFlag(
        ['vmodule'], 'logger.name=LEVEL[,...]',
        "Customized verbose logging. `logger.name` can be a class or package\n"+
        "\t(e.g. org.mirah.jvm or org.mirah.tool.Mirahc)\n"+
        "\t`LEVEL` should be one of \n"+
        "\t(SEVERE, WARNING, INFO, CONFIG, FINE, FINER FINEST)") do |spec|
      split = spec.split(',')
      i = 0
      while i < split.length
        pieces = split[i].split("=", 2)
        i += 1
        logger = Logger.getLogger(pieces[0])
        level = Level.parse(pieces[1])
        logger.setLevel(level)
      end
    end
    parser.addFlag(
        ['classpath', 'cp'], 'CLASSPATH',
        "A #{File.pathSeparator} separated list of directories, JAR \n"+
        "\tarchives, and ZIP archives to search for class files.") do |classpath|
      mirahc.setClasspath(classpath)
    end
    parser.addFlag(
        ['bootclasspath'], 'CLASSPATH',
        "Classpath to search for standard JRE classes."
    ) do |classpath|
      mirahc.setBootClasspath(classpath)
    end
    parser.addFlag(
        ['macroclasspath'], 'CLASSPATH',
        "Classpath to use when compiling macros."
    ) do |classpath|
      mirahc.setMacroClasspath(classpath)
    end
    parser.addFlag(
        ['dest', 'd'], 'DESTINATION',
        'Directory where class files should be saved.'
    ) {|dest| mirahc.setDestination(dest) }
    parser.addFlag(['all-errors'],
        'Display all compilation errors, even if there are a lot.') {
      mirahc.setMaxErrors(-1)
    }
    it = parser.parse(args).iterator
    while it.hasNext
      f = String(it.next)
      @code_sources.add(StreamCodeSource.new(f))
    end
  end

  def parseAllFiles
    @code_sources.each do |c:CodeSource|
      parse(c)
    end
  end

  def self.main(args:String[]):void
    mirahc = Mirahc.new(args)
    mirahc.parseAllFiles
    mirahc.infer
    mirahc.compile
  rescue TooManyErrorsException
    puts "Too many errors, exiting."
  end
end