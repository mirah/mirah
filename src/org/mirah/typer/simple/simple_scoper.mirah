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
import mirah.impl.MirahParser
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.FileInputStream
import java.io.PrintStream

interface ScopeFactory do
  def newScope(scoper: Scoper, node: Node): Scope; end
end

# A minimal Scoper.
class SimpleScoper; implements Scoper

  def initialize(factory: ScopeFactory)
    @factory = factory
    @scopes = {}
  end

  def getScope(node)
    orig = node
    until node.parent.nil?
      node = node.parent
      scope = getIntroducedScope node
      return scope if scope
    end
    getIntroducedScope(node) || addScope(node)
  end

  def getIntroducedScope(node: Node)
    @scopes[node].as! Scope
  end

  def addScope(node)
    @scopes[node].as!(Scope) || begin
      scope = @factory.newScope(self, node)
      @scopes[node] = scope
      scope
    end
  end

  def setScope(node: Node, scope: Scope)
    @scopes[node] = scope
  end

  def copyScopeFrom(from, to)
    @scopes[to] = getScope(from)
  end
end
