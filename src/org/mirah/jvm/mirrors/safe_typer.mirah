# Copyright (c) 2012 The Mirah project authors. All Rights Reserved.
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

package org.mirah.jvm.mirrors

import org.mirah.util.Logger
import java.util.logging.Level
import javax.tools.DiagnosticListener
import mirah.impl.MirahParser
import mirah.lang.ast.Node
import mirah.lang.ast.Script
import org.mirah.macros.JvmBackend
import org.mirah.typer.Scoper
import org.mirah.typer.TypeSystem
import org.mirah.typer.Typer
import org.mirah.util.Context
import org.mirah.util.MirahDiagnostic
import org.mirah.jvm.compiler.ReportedException

class SafeTyper < Typer
  def self.initialize:void
    @@log = Logger.getLogger(SafeTyper.class.getName)
  end

  def initialize(context: Context,
                 types: TypeSystem,
                 scopes: Scoper,
                 jvm_backend: JvmBackend,
                 parser: MirahParser=nil)
    super(types, scopes, jvm_backend, parser)
    @diagnostics = context[DiagnosticListener]
  end

  def infer(node:Node, expression:boolean)
    super
  rescue => ex
    raise betterException(ex, node)
  end

  def finish_closures
    super
  rescue => ex
    raise betterException(ex)
  end

  def betterException(ex: Throwable, node: Node=nil): Throwable
    if ex.kind_of?(ReportedException)
      ReportedException.new(ex.getCause)
    elsif ex.getCause.kind_of?(ReportedException)
      ex.getCause
    # For test running, otherwise you get Internal compiler error over and over
    elsif ex.getClass.getName.equals "org.jruby.exceptions.RaiseException"
      ex
    else
      if @@log.isLoggable Level.FINE
        @@log.log Level.SEVERE, "Exception in typer for #{node}\n  #{sourceContent node}", ex
      end
      @diagnostics.report(MirahDiagnostic.error(node && node.position, "Internal compiler error: #{ex} #{ex.getMessage}. Rerun in verbose mode for stacktrace."))

      ReportedException.new(ex)
    end
  end
end