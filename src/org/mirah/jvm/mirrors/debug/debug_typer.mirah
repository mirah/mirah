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

package org.mirah.jvm.mirrors.debug

import org.mirah.util.Logger
import javax.tools.DiagnosticListener
import mirah.impl.MirahParser
import mirah.lang.ast.Node
import mirah.lang.ast.Script
import org.mirah.macros.JvmBackend
import org.mirah.typer.Scoper
import org.mirah.typer.TypeSystem
import org.mirah.typer.Typer
import org.mirah.typer.TypeFuture
import org.mirah.util.Context
import org.mirah.util.MirahDiagnostic
import org.mirah.jvm.compiler.ReportedException
import org.mirah.jvm.mirrors.SafeTyper

interface DebuggerInterface
  def parsedNode(node:Node):void; end
  def enterNode(context:Context, node:Node, expression:boolean):void; end
  def exitNode(context:Context, node:Node, future:TypeFuture):void; end
  def inferenceError(context:Context, node:Node, future:TypeFuture):void; end
end

class DebugTyper < SafeTyper
  def self.initialize:void
    @@log = Logger.getLogger(SafeTyper.class.getName)
  end

  def initialize(
    debugger:DebuggerInterface,
    context:Context,
    types:TypeSystem,
    scopes:Scoper,
    jvm_backend:JvmBackend,
    parser:MirahParser=nil)
    super(context, types, scopes, jvm_backend, parser)
    @debugger = debugger
    @context = context
  end

  def infer(node:Node, expression:boolean)
    @debugger.enterNode(@context, node, expression)
    result = super
    @debugger.exitNode(@context, node, result)
    result
  end
end