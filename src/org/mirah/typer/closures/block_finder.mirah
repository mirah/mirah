# Copyright (c) 2012-2015 The Mirah project authors. All Rights Reserved.
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

package org.mirah.typer.closures

import mirah.lang.ast.*

import org.mirah.typer.Typer
import org.mirah.typer.CallFuture
import org.mirah.typer.TypeFuture

import java.util.Map
import java.util.LinkedHashMap

class BlockFinder < NodeScanner
  def initialize(typer: Typer, todo_closures: Map)
    @typer = typer
    @todo_closures = todo_closures
  end
  def find(node: Script): Map
    collection = LinkedHashMap.new
    node.accept(self, collection)
    collection
  end

  def enterMacroDefinition(node, notes)
    false
  end

  def exitBlock(node, notes)
    type = if @todo_closures[node]
      @todo_closures[node]
    else
      #t = @typer.getResolvedType(node)
      #if t.kind_of? MethodType
        parent_type_future = @typer.getInferredType(node.parent)
        unless parent_type_future
          puts "#{CallSite(node.parent).name.identifier} call with block has no type at #{node.parent.position}"
          puts "  block type: #{@typer.getInferredType(node)}"
          # If parent_type_future is nil, then there's likely another type error somewhere.
          # So just ignore this block and it'll bubble up.
          return nil
        end
        fs = CallFuture(parent_type_future).futures
        TypeFuture(fs.get(fs.size-1)).resolve
      #else
      #end
    end
    Map(notes).put node, type
  end
end
