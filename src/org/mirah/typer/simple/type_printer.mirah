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

package org.mirah.typer.simple

import java.util.*
import org.mirah.typer.*
import mirah.lang.ast.NodeScanner
import mirah.lang.ast.Node
import mirah.lang.ast.Position
import mirah.lang.ast.StreamCodeSource
import mirah.impl.MirahParser
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.FileInputStream
import java.io.PrintStream

# Prints an AST along with its inferred types.
class TypePrinter < NodeScanner
  def initialize(typer:Typer)
    initialize(typer, System.out)
  end

  def initialize(typer:Typer, writer:PrintStream)
    @indent = 0
    @typer = typer
    @args = Object[1]
    @args[0] = ""
    @out = writer
  end
  def printIndent:void
    @out.printf("%#{@indent}s", @args) if @indent > 0
  end
  def enterDefault(node, arg)
    printIndent
    @out.print(node)
    type = @typer.getInferredType(node)
    if type
      @out.print ": #{type.resolve}"
    end
    @out.println
    @indent += 2
    true
  end
  def enterUnquote(node, arg)
    super(node, arg)
    if node.object
      if node.object.kind_of?(Node)
        Node(node.object).accept(self, arg)
      else
        printIndent
        @out.print node.object
        @out.println
      end
    end
    node.object.nil?
  end
  def exitDefault(node, arg)
    @indent -= 2
    nil
  end
end
