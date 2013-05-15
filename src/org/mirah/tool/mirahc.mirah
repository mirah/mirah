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
import java.util.logging.Level
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
import org.mirah.typer.simple.TypePrinter
import org.mirah.typer.Typer
import org.mirah.util.SimpleDiagnostics

class Mirahc implements JvmBackend
  def initialize
    logger = MirahLogFormatter.new(true).install
    logger.setLevel(Level.ALL)
    @diagnostics = SimpleDiagnostics.new(true)
    @types = MirrorTypeSystem.new
    @scoper = SimpleScoper.new do |s, node|
      scope = JVMScope.new(s)
      scope.context = node
      scope
    end
    @typer = Typer.new(@types, @scoper, self)
    @parser = MirahParser.new
    BaseParser(@parser).diagnostics = @diagnostics
    @backend = Backend.new(@typer)
    @asts = []
  end

  def parse(code:CodeSource)
    @asts.add(@parser.parse(code))
    if @diagnostics.errorCount > 0
      System.exit(1)
    end
  end

  def infer
    @asts.each do |n|
      node = Node(n)
      begin
        @typer.infer(node, false)
      ensure
        TypePrinter.new(@typer, System.out).scan(node, nil)
      end
    end
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

  def self.main(args:String[]):void
    mirahc = Mirahc.new
    inline = false
    args.each do |arg|
      if inline
        mirahc.parse(StringCodeSource.new('DashE', arg))
        inline = false
      elsif '-e'.equals(arg)
        inline = true
      else
        mirahc.parse(StreamCodeSource.new(arg))
      end
    end
    mirahc.infer
    mirahc.compile
  end
end