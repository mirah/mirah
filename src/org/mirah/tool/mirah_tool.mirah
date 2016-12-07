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
import org.mirah.util.Logger
import java.util.logging.Level
import java.util.regex.Pattern
import javax.tools.DiagnosticListener
import mirah.impl.MirahParser
import mirah.lang.ast.CodeSource
import mirah.lang.ast.Node
import mirah.lang.ast.Script
import mirah.lang.ast.StringCodeSource
import org.mirah.IsolatedResourceLoader
import org.mirah.MirahClassLoader
import org.mirah.MirahLogFormatter
import org.mirah.jvm.compiler.Backend
import org.mirah.jvm.compiler.BytecodeConsumer
import org.mirah.jvm.compiler.JvmVersion
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.jvm.mirrors.ClassResourceLoader
import org.mirah.jvm.mirrors.ClassLoaderResourceLoader
import org.mirah.jvm.mirrors.FilteredResources
import org.mirah.jvm.mirrors.SafeTyper
import org.mirah.jvm.mirrors.debug.ConsoleDebugger
import org.mirah.jvm.mirrors.debug.DebuggerInterface
import org.mirah.macros.JvmBackend
import org.mirah.mmeta.BaseParser
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
  def initialize
    reset
  end

  def self.initialize:void
    @@log = Logger.getLogger(Mirahc.class.getName)
  end

  def reset
    @compiler_args = MirahArguments.new
  end

  def setDiagnostics(diagnostics: SimpleDiagnostics):void
    @compiler_args.diagnostics = diagnostics
  end

  def compile(args:String[]):int
    @compiler_args.applyArgs(args)
    if @compiler_args.exit?
      return @compiler_args.exit_status
    end

    @compiler_args.setup_logging

    if compiler_args.use_type_debugger && !@debugger
      debugger = ConsoleDebugger.new
      debugger.start
      @debugger = debugger.debugger
    end

    diagnostics = @compiler_args.diagnostics

    diagnostics.setMaxErrors(@compiler_args.max_errors)

    @compiler = MirahCompiler.new(
        diagnostics,
        @compiler_args.jvm_version,
        @compiler_args.real_classpath,
        @compiler_args.real_bootclasspath,
        @compiler_args.real_macroclasspath,
        @compiler_args.destination,
        @compiler_args.real_macro_destination,
        @debugger)
    parseAllFiles
    @compiler.infer
    @compiler.compile(self)
    0
  rescue TooManyErrorsException
    puts "Too many errors."
    1
  rescue CompilationFailure
    puts "#{diagnostics.errorCount} errors"
    1
  end

  def setDestination(dest:String):void
    @compiler_args.destination = dest
  end

  def destination
    @compiler_args.destination
  end

  def setClasspath(classpath:String):void
    @compiler_args.classpath = classpath
  end

  def classpath
    @compiler_args.real_classpath
  end

  def setBootClasspath(classpath:String):void
    @compiler_args.bootclasspath = classpath
  end

  def setMacroClasspath(classpath:String):void
    @compiler_args.macroclasspath = classpath
  end

  def setMaxErrors(count:int):void
    @compiler_args.max_errors = count
  end

  def setJvmVersion(version:String):void
    @compiler_args.jvm_version = JvmVersion.new(version)
  end

  def setDebugger(debugger:DebuggerInterface):void
    @debugger = debugger
  end

  def addFakeFile(name:String, code:String):void
    @compiler_args.code_sources.add(StringCodeSource.new(name, code))
  end

  def parseAllFiles
    @compiler_args.code_sources.each do |c:CodeSource|
      @compiler.parse(c)
    end
  end

  def compiler
    @compiler
  end
end