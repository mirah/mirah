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
import java.util.List
import java.util.logging.Logger
import java.util.logging.Level
import javax.tools.DiagnosticListener
import mirah.impl.MirahParser
import mirah.lang.ast.CodeSource
import mirah.lang.ast.Node
import mirah.lang.ast.Script
import mirah.lang.ast.StreamCodeSource
import mirah.lang.ast.StringCodeSource
import org.mirah.MirahLogFormatter
import org.mirah.jvm.compiler.Backend
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.jvm.mirrors.JVMScope
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
  @@VERSION = "0.1.1.dev"

  def initialize(args:String[])
    @logger = MirahLogFormatter.new(true).install
    @code_sources = []
    processArgs(args)
    @context = context = Context.new
    context[JvmBackend] = self
    context[DiagnosticListener] = @diagnostics = SimpleDiagnostics.new(true)
    context[SimpleDiagnostics] = @diagnostics
    context[TypeSystem] = @types = MirrorTypeSystem.new(context)
    context[Scoper] = @scoper = SimpleScoper.new do |s, node|
      scope = JVMScope.new(s)
      scope.context = node
      scope
    end
    context[MirahParser] = @parser = MirahParser.new
    BaseParser(@parser).diagnostics = ParserDiagnostics.new(@diagnostics)
    context[Typer] = @typer = Typer.new(@types, @scoper, self, @parser)
    @backend = Backend.new(context)
    @asts = []
  end

  def self.initialize:void
    @@log = Logger.getLogger(Mirahc.class.getName)
  end

  def parse(code:CodeSource)
    @asts.add(@parser.parse(code))
    if @diagnostics.errorCount > 0
      System.exit(1)
    end
  end

  def infer
    @asts.each do |node:Node|
      begin
        @typer.infer(node, false)
      ensure
        logAst(node)
      end
    end
    errors = ErrorCollector.new(@context)
    @asts.each do |node:Node|
      errors.scan(node, nil)
    end
    if @diagnostics.errorCount > 0
      System.exit(1)
    end
  end

  def logAst(node:Node)
    @@log.log(Level.FINE, "Inferred types:\n{0}", LazyTypePrinter.new(@typer, node))
  end

  def logExtensionAst(ast)
    @@log.log(Level.FINE, "Inferred types:\n{0}", AstFormatter.new(ast))
  end

  def compile
    @asts.each do |n|
      node = Script(n)
      @backend.visit(node, nil)
    end
    @backend.generate do |filename, bytes|
      file = File.new("#{filename.replace(?., ?/)}.class")
      parent = file.getParentFile
      parent.mkdirs if parent
      output = BufferedOutputStream.new(FileOutputStream.new(file))
      output.write(bytes)
      output.close
    end
  end

  def processArgs(args:String[]):void
    parser = OptionParser.new("Mirahc [flags] <files or -e SCRIPT>")
    parser.addFlag(["h", "help"], "Print this help message.") do
      parser.printUsage
      System.exit(0)
    end
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