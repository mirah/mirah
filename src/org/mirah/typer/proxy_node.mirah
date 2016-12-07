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

package org.mirah.typer

import java.util.ArrayList
import java.util.Collections
import java.util.List
import java.util.NoSuchElementException
import mirah.lang.ast.Identifier
import mirah.lang.ast.Node
import mirah.lang.ast.NodeList
import mirah.lang.ast.NodeVisitor
import mirah.lang.ast.TypeName
import mirah.lang.ast.Unquote

class ProxyNode < NodeList implements TypeName, Identifier
  def initialize(typer:Typer, node:Node)
    super(node.position)
    @typer = typer
    node.parent.replaceChild(node, self)
    node.setParent(self)
    @original = node
  end
  
  #def accept(visitor:NodeVisitor, arg:Object):Object
  #  if @selectedNode
  #    #puts "WHOOO accepting proxy node w/ selected #{@selectedNode}"
  #    @selectedNode.accept visitor, arg
  #  else
  #    @original.accept visitor, arg
  #  end
  #end

  def clone
    #if @selectedNode
    #  cloned = Node(@selectedNode.clone)
    #  fireWasCloned(cloned)
    #  cloned
    #else
      cloned = Node(@original.clone)
      fireWasCloned(cloned)
      cloned
    #end
  end

  def size
    1
  end

  def get(i)
    if i == 0
      @selectedNode
    else
      raise NoSuchElementException, "No element #{i}"
    end
  end

  def identifier
    @unquote ||= Unquote.new
    @unquote.identifierNode(@selectedNode).identifier
  end

  def typeref
    @nodes.each do |n|
      if n.kind_of?(TypeName)
        return TypeName(n).typeref
      end
    end
    nil
  end

  def add(node)
    raise UnsupportedOperationException, "ProxyNode doesn't support add"
  end

  def insert(i, value)
    raise UnsupportedOperationException, "ProxyNode doesn't support insert"
  end

  def set(i, value)
    raise UnsupportedOperationException, "ProxyNode doesn't support set"
  end

  def remove(i)
    raise UnsupportedOperationException, "ProxyNode doesn't support remove"
  end

  def removeChild(node)
    raise UnsupportedOperationException, "ProxyNode doesn't support removeChild"
  end

  def setChildren(nodes:List, defaultChild:int=-1):void
    if defaultChild < 0
      defaultChild += nodes.size
    end
    @defaultChild = defaultChild

    nodeCount = nodes.size
    newNodes = ArrayList.new(nodeCount)

    @futures = Collections.emptyList
    @future = nil

    nodes.size.times do |i|
      node = childAdded(Node(nodes[i]))
      newNodes.add(node)
    end
    @nodes = newNodes
    @selectedNode = Node(@nodes.get(@defaultChild))
  end

  def inferChildren(expression:boolean):TypeFuture
    if @future.nil?
      @expression = expression
      @future = DelegateFuture.new
      @futures = @nodes.map {|n:Node| @typer.infer(n, expression)}
      @selectedNode = Node(@nodes.get(@defaultChild))
      @future.type = DerivedFuture.new(TypeFuture(@futures.get(@defaultChild))) do
        |resolved|
        if resolved.kind_of?(InlineCode)
          nil
        else
          resolved
        end
      end
      proxy = self
      listener = lambda(TypeListener) do |x, resolved|
        proxy.updateSelection
      end
      @futures.each {|f:TypeFuture| f.onUpdate(listener)}
    end
    @future
  end

  def updateSelection:void
    @futures.size.times do |i|
      f = TypeFuture(@futures.get(i))
      if f.isResolved
        resolved = f.resolve
        unless resolved.isError
          selectNode(i, Node(@nodes.get(i)), f, resolved)
          return
        end
      end
    end
    selectNode(-1, Node(@nodes.get(@defaultChild)), TypeFuture(@futures.get(@defaultChild)), nil)
  end

  def selectNode(index:int, node:Node,
                 future:TypeFuture, resolved:ResolvedType):void
    if resolved.kind_of?(InlineCode)
      @selectedNode = childAdded(@typer.expandMacro(node, resolved))
      @future.type = @typer.infer(@selectedNode, @expression)
    else
      @selectedNode = node
      @future.type = future
    end
  end

  def replaceChild(child, newChild)
    import static org.mirah.util.Comparisons.*
    if areSame(child, newChild)
      return newChild
    end
    clone = childAdded(newChild)
    i = @nodes.indexOf(child)
    if i != -1
      @nodes.set(i, clone)
    end
    child.setParent(nil)
    if areSame(child, @selectedNode)
      @selectedNode = clone
    end
    clone
  end

  def toString
    "<org.mirah.typer.ProxyNode: selected:#{@selectedNode}>"
  end
  
  def self.dereference(node:Node)
    if node.kind_of?(ProxyNode)
      ProxyNode(node).dereference
    else
      node
    end
  end
  
  def dereference
    dereference(@selectedNode)
  end
end