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
import org.mirah.jvm.mirrors.SafeTyper
import org.mirah.jvm.mirrors.debug.ConsoleDebugger
import org.mirah.jvm.mirrors.debug.DebuggerInterface
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

abstract class MirahTool implements BytecodeConsumer
  @@VERSION = "0.1.2.dev"

  def initialize
    @logger = MirahLogFormatter.new(true).install
    reset
  end

  attr_reader destination:String

  def self.initialize:void
    @@log = Logger.getLogger(Mirahc.class.getName)
  end

  def reset
    @code_sources = []
    @destination = "."
    @diagnostics = SimpleDiagnostics.new(true)
    @jvm = JvmVersion.new
    @classpath = nil
  end

  def setDiagnostics(diagnostics:SimpleDiagnostics):void
    @diagnostics = diagnostics
  end

  def compile(args:String[]):int
    processArgs(args)
    @classpath ||= parseClassPath(@destination)

    @compiler = MirahCompiler.new(
        @diagnostics, @jvm, @classpath, @bootcp, @macrocp, @destination,
        @debugger)
    parseAllFiles
    @compiler.infer
    @compiler.compile(self)
    0
  rescue TooManyErrorsException
    puts "Too many errors."
    1
  rescue CompilationFailure
    puts "#{@diagnostics.errorCount} errors"
    1
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
  def classpath
    @classpath
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

  def setJvmVersion(version:String):void
    @jvm = JvmVersion.new(version)
  end

  def enableTypeDebugger:void
    debugger = ConsoleDebugger.new
    debugger.start
    @debugger = debugger.debugger
  end
  
  def setDebugger(debugger:DebuggerInterface):void
    @debugger = debugger
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
      System.exit(0)
    end
    logger = @logger
    parser.addFlag(['V', 'verbose'], 'Verbose logging.') do
      logger.setLevel(Level.FINE)
    end
    vloggers = @vloggers = HashSet.new
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
        vlogger = Logger.getLogger(pieces[0])
        level = Level.parse(pieces[1])
        vlogger.setLevel(level)
        vloggers.add(vlogger)
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
    parser.addFlag(
        ['jvm'], 'VERSION',
        'Emit JVM bytecode targeting specified JVM version (1.5, 1.6, 1.7)'
    ) { |v| mirahc.setJvmVersion(v) }
    parser.addFlag(
        ['tdb'], 'Start the interactive type debugger.'
    ) { mirahc.enableTypeDebugger }

    it = parser.parse(args).iterator
    while it.hasNext
      f = File.new(String(it.next))
      addFileOrDirectory(f)
    end
  end

  def addFileOrDirectory(f:File):void
    unless f.exists
      puts "No such file #{f.getPath}"
      System.exit(1)
    end
    if f.isDirectory
      f.listFiles.each do |c|
        if c.isDirectory || c.getPath.endsWith(".mirah")
          addFileOrDirectory(c)
        end
      end
    else
      @code_sources.add(StreamCodeSource.new(f.getPath))
    end
  end

  def addFakeFile(name:String, code:String):void
    @code_sources.add(StringCodeSource.new(name, code))
  end

  def parseAllFiles
    @code_sources.each do |c:CodeSource|
      @compiler.parse(c)
    end
  end

  def compiler
    @compiler
  end
end