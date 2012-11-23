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

package org.mirah.jvm.compiler

import javax.tools.DiagnosticListener
import mirah.lang.ast.Node
import mirah.lang.ast.Position
import mirah.lang.ast.SimpleNodeVisitor
import org.mirah.jvm.types.JVMType
import org.mirah.util.Context
import org.mirah.util.MirahDiagnostic
import org.mirah.typer.Typer

class ReportedException < RuntimeException
  def initialize(ex:Throwable)
    super(ex)
  end
end

class BaseCompiler < SimpleNodeVisitor
  attr_reader context:Context
  
  def initialize(context:Context)
    @context = context
    @typer = context[Typer]
  end
  
  def reportError(message:String, position:Position)
    @context[DiagnosticListener].report(MirahDiagnostic.error(position, message))
  end
  
  def reportNote(message:String, position:Position)
    @context[DiagnosticListener].report(MirahDiagnostic.note(position, message))
  end
  
  def reportWarning(message:String, position:Position)
    @context[DiagnosticListener].report(MirahDiagnostic.warning(position, message))
  end

  def reportICE(ex:Throwable, position:Position):RuntimeException
    if ex.kind_of?(ReportedException)
      raise ex
    else
      reportError("Internal error: #{ex.getMessage}", position)
      raise ReportedException.new(ex)
    end
  end

  def getInferredType(node:Node):JVMType
    begin
      JVMType(@typer.getInferredType(node).resolve)
    rescue Exception => ex
      raise reportICE(ex, node.position)
    end
  end

  def defaultNode(node, arg)
    reportError("#{getClass} can't compile node #{node.getClass}", node.position)
  end

  def visit(node:Node, arg:Object)
    begin
      node.accept(self, arg)
    rescue ReportedException => ex
      raise ex
    rescue Throwable => ex
      reportICE(ex, node.position)
    end
  end

  def visitNodeList(nodes, arg)
    nodes.each {|n| visit(Node(n), arg)}
  end
  
  def visitPackage(node, arg)
    visit(node.body, arg) if node.body
  end
  
  def visitImport(node, arg)
  end
  
  def visitUnquote(node, arg)
    node.nodes.each {|n| visit(Node(n), arg)}
  end
end