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

import java.util.List
import java.util.HashSet
import org.mirah.util.Logger
import javax.tools.DiagnosticListener
import mirah.lang.ast.NodeScanner
import mirah.lang.ast.Position
import mirah.lang.ast.Node
import org.mirah.jvm.mirrors.debug.DebuggerInterface
import org.mirah.typer.ErrorMessage
import org.mirah.typer.ErrorType
import org.mirah.typer.FuturePrinter
import org.mirah.typer.Typer
import org.mirah.util.Context
import org.mirah.util.MirahDiagnostic


class ErrorCollector < NodeScanner
  def initialize(context:Context)
    @errors = HashSet.new
    @typer = context[Typer]
    @reporter = context[DiagnosticListener]
    @debugger = context[DebuggerInterface]
    @context = context
  end

  def self.initialize:void
    @@log = Logger.getLogger(ErrorCollector.class.getName)
  end

  def exitDefault(node, arg)
    future = @typer.getInferredType(node)
    type = future.nil? ? nil : future.resolve
    if (type && type.isError)
      if @errors.add(type)
        messages = type.as!(ErrorType).messages
        diagnostic = build_diagnostic messages, node
        @reporter.report(diagnostic)
        debug = FuturePrinter.new
        debug.printFuture(future)
        @@log.fine("future:\n#{debug}")
        if @debugger
          @debugger.inferenceError(@context, node, future)
        end
      end
    end
    nil
  end

  def enterBlock(node, arg)
    # There must have already been an error for the method call, so ignore this.
    false
  end

  def build_diagnostic(messages: List, node: Node)
    if messages.empty?
      return MirahDiagnostic.error(node.position, "Error")
    elsif messages.size == 1 || messages.size > 1 # TODO if there is more than one message, do something better.
      error_msg = messages[0].as!(ErrorMessage)
      text = error_msg.message
      position = error_msg.position || node.position

      MirahDiagnostic.error(position, text)
    end
  end
end
