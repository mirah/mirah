# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
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

package org.mirahparser.ast

import mirah.lang.ast.Block
import mirah.lang.ast.CallSite
import mirah.lang.ast.Constant
import mirah.lang.ast.Hash
import mirah.lang.ast.Identifier
import mirah.lang.ast.Node
import mirah.lang.ast.NodeList
import mirah.lang.ast.SimpleString
import mirah.lang.ast.ClassDefinition
import mirah.lang.ast.TypeNameList

import org.mirah.macros.Compiler
import java.lang.ref.WeakReference
import java.util.ArrayList
import java.util.Collections
import java.util.HashMap
import java.util.List
import java.util.WeakHashMap

class MetaTool
  def initialize(mirah:Compiler)
    @mirah = WeakReference.new(mirah)
  end

  def mirah:Compiler
    Compiler(@mirah.get)
  end

  def enclosing_class(node:Node):ClassDefinition
    node = node.parent until node.nil? || node.kind_of?(ClassDefinition)
    ClassDefinition(node)
  end
end

class VisitorState < MetaTool
  def initialize(mirah:Compiler)
    super(mirah)
    @ivisitor = NodeList.new
    @simple_classdef = mirah.quote do
      class SimpleNodeVisitor implements NodeVisitor
      end
    end
    @simple = @simple_classdef.body
    @scanner_classdef= mirah.quote do
      class NodeScanner implements NodeVisitor
      end
    end
    @scanner = @scanner_classdef.body
  end

  def init_visitor(call:CallSite):Node
    enclosing_class(call).body.add(@ivisitor)
    top = NodeList(enclosing_class(call).parent)
    top.add(@simple_classdef)
    top.add(@scanner_classdef)
    @simple.add(mirah.quote do
      def defaultNode(node:Node, arg:Object):Object
        nil
      end
    end)
    @scanner.add(mirah.quote do
      def enterDefault(node:Node, arg:Object):boolean
        true
      end

      def exitDefault(node:Node, arg:Object):Object
        nil
      end

      def enterNullChild(arg:Object):Object
        nil
      end

      def scan(node:Node, arg:Object=nil):Object
        if node.nil?
          enterNullChild(arg)
        else
          node.accept(self, arg)
        end
      end
    end)
    mirah.typer.infer(@simple_classdef)
    mirah.typer.infer(@scanner_classdef)
    addNode('Node', nil, 'Other')
    nil
  end

  def addList(type:String)
    children = mirah.quote do
      node.size.times do |i|
        scan(node.get(i), arg)
      end
    end
    addNode(type, type, children)
  end

  def addNode(type:String, name:String, scanChildren:Node)
    name ||= type
    node = mirah.quote do
      def `"visit#{name}"`(node: `type`, arg:Object):Object; end
    end
    @ivisitor.add(node)
    mirah.typer.infer(node)
    
    node = mirah.quote do
      def `"visit#{name}"`(node: `type`, arg:Object):Object
        defaultNode(node, arg)
      end
    end
    @simple.add(node)
    mirah.typer.infer(node)
    addScanner(scanner, type, name, scanChildren)
  end

  def addScanner(scanner:NodeList, type:String, name:String, scanChildren:Node)
    nodes = mirah.quote do
      def `"enter#{name}"`(node: `type`, arg:Object):boolean
        enterDefault(node, arg)
      end

      def `"exit#{name}"`(node: `type`, arg:Object):Object
        exitDefault(node, arg)
      end

      def `"visit#{name}"`(node: `type`, arg:Object):Object
        if self.`"enter#{name}"`(node, arg)
          `scanChildren`
        end
        self.`"exit#{name}"`(node, arg)
      end
    end
    scanner.add(nodes)
    mirah.typer.infer(nodes)
  end

  def addNode(type:String, children:List, name:String=nil)
    childScanner = NodeList.new
    if children
      children.each do |c|
        child_name = List(c).get(0)
        child_type = String(List(c).get(1))
        childScanner.add(mirah.quote do
          scan(node.`child_name`, arg)
        end)
      end
    end
    addNode(type, name, childScanner)
  end

  def ivisitor:NodeList
    @ivisitor
  end
  def simple
    @simple
  end
  def scanner
    @scanner
  end
end

class BaseNodeState < MetaTool
  def initialize(mirah:Compiler, node:Node)
    super(mirah)
    @klass = enclosing_class(node)
  end

  def name
    @klass.name.identifier
  end
end

class ListNodeState < BaseNodeState
  def initialize(mirah:Compiler, type:Node, visitors:VisitorState)
    super(mirah, type)
    @visitors = visitors
    raise NullPointerException if visitors.nil?
  end

  def init_list(type:Identifier)
    type_name = type.identifier
    visitor_method = "visit#{name}"
    @visitors.addList(name)
    iterator_name = "#{name}Iterator"
    interfaces = enclosing_class(type).interfaces
    if interfaces.nil?
      enclosing_class(type).interfaces = interfaces = TypeNameList.new
      mirah.typer.infer(interfaces)
    end
    iterable = Constant.new(SimpleString.new("Iterable"))
    interfaces.add(iterable)
    mirah.typer.infer(iterable)
    mirah.quote do
      import java.util.Iterator
      import java.util.ListIterator
      import java.util.List

      def common_init(size:int):void
        if size < 0
          @children = java::util::ArrayList.new
        else
          @children = java::util::ArrayList.new(size)
        end
      end

      def initialize()
        common_init(-1)
      end

      def initialize(position:Position)
        self.position = position
        common_init(-1)
      end

      def initialize(children:List)
        if children
          common_init(children.size)
          startPosition = nil
          endPosition = nil
          children.each do |_node:Node|
            node = Node(_node)
            if node
              @children.add(childAdded(node))
              startPosition ||= node.position
              endPosition = node.position
            end
          end
          unless @children.isEmpty
            self.position = startPosition + endPosition
          end
        else
          common_init(-1)
        end
        nil
      end

      def initialize(position:Position, children:List)
        self.position = position
        if children
          common_init(children.size)
          children.each {|node:Node| @children.add(childAdded(Node(node)))}
        else
          common_init(-1)
        end
        nil
      end

      def size:int
        @children.size
      end

      def get(i:int): `type_name`
        child = @children.get(i)
        `mirah.cast(type_name, 'child')`
      end

      def set(i:int, node:`type_name`): `type_name`
        current = get(i)
        if current != node
          childRemoved(current)
          @children.set(i, childAdded(node))
        end
        node
      end

      def replaceChild(oldChild:Node, newChild:Node):Node
        if oldChild == newChild
          return newChild
        end
        i = @children.indexOf(oldChild)
        clone = childAdded(newChild)
        set(i, `mirah.cast(type_name, 'clone')`)
        clone.setOriginalNode(oldChild)
        clone
      end

      def removeChild(child:Node):void
        @children.remove(child)
      end

      def initCopy:void
        super
        new_children = java::util::ArrayList.new(@children.size)
        @children.each {|child| new_children.add(child ? childAdded(Node(Node(child).clone)) : nil)}
        @children = new_children
      end

      def add(node:`type_name`):void
        @children.add(childAdded(node))
      end

      def insert(i:int, node:`type_name`):void
        @children.add(i, childAdded(node))
      end

      def remove(i:int): `type_name`
        node = Node(@children.remove(i))
        childRemoved(node)
        `mirah.cast(type_name, 'node')`
      end

      def accept(visitor, arg):Object
        visitor.`visitor_method`(self, arg)
      end

#      public
      def iterator:Iterator
        listIterator(0)
      end

      def listIterator(start:int = 0):ListIterator
        `iterator_name`.new(self, start)
      end
      
      class `iterator_name` implements java.util.ListIterator
        def initialize(list:`name`, start:int)
          raise IndexOutOfBoundsException if (start < 0 || start > list.size)
          @nextIndex = start
          @lastIndex = -1
          @listNode = list
        end

        def add(o)
          node = `mirah.cast(type_name, 'o')`
          @listNode.insert(@nextIndex, node)
          @nextIndex += 1
          @lastIndex = -1
        end

        def hasPrevious
          @nextIndex > 0
        end

        def hasNext
          @nextIndex < @listNode.size
        end

        def next
          if @nextIndex < @listNode.size
            @lastIndex = @nextIndex
            @nextIndex += 1
          else
            @lastIndex = -1
            raise java::util::NoSuchElementException
          end
          @listNode.get(@nextIndex - 1)
        end

        def nextIndex
          @nextIndex
        end

        def previous
          if @nextIndex > 0
            @nextIndex -= 1
            @lastIndex = nextIndex
          else
            @lastIndex = -1
            raise java::util::NoSuchElementException
          end
          @listNode.get(@nextIndex)
        end

        def previousIndex
          @nextIndex - 1
        end

        def remove
          if @lastIndex == -1 || @lastIndex == @listNode.size
            raise IllegalStateException
          end
          @listNode.remove(@lastIndex)
          @nextIndex = @lastIndex
          @lastIndex = -1
        end

        def set(o)
          if @lastIndex == -1 || @lastIndex == @listNode.size
            raise IllegalStateException
          end
          node = `mirah.cast(type_name, 'o')`
          @listNode.set(@lastIndex, node)
        end
      end
    end
  end
end

class NodeState < BaseNodeState
  def initialize(mirah:Compiler, node:Node, visitors:VisitorState)
    super(mirah, node)
    raise NullPointerException if visitors.nil?
    @visitors = visitors
    @children = ArrayList.new
    @constructor = NodeList.new
    @replaceNodeList = NodeList.new
    @removeNodeList = NodeList.new
    @cloneNodeList = NodeList.new
  end

  def init_node(block:Block)
    name = self.name
    if block
      extra_setup = mirah.quote do
        `block.body`
        add_constructor(`name`)
      end
    else
      @visitors.addNode(name, nil)
      extra_setup = NodeList.new
    end
    visitor_method = "visit#{name}"
    mirah.quote do

      def initialize()
      end

      def initialize(position:Position)
        self.position = position
      end

      def accept(visitor, arg):Object
        visitor.`visitor_method`(self, arg)
      end

      `extra_setup`
    end
  end

  def init_subclass(parent:NodeState)
    visitor_method = "visit#{name}"

    mirah.quote do
      def initialize()
      end

      def initialize(position:Position)
        self.position = position
      end
      `parent.addConstructor(name)`

      def accept(visitor, arg):Object
        visitor.`visitor_method`(self, arg)
      end
    end
  end

  def init_literal(type:Identifier)
    name = SimpleString.new(self.name)
    mirah.quote do
      `init_node(nil)`
      `child('value', type.identifier, false)`
      def initialize(value:`type`)
        @value = value
      end
      def initialize(position:Position, value:`type`)
        self.position = position
        @value = value
      end
      def toString
        "<#{`name`}:#{value}>"
      end
    end
  end

  def addConstructor(name:String=nil)
    @visitors.addNode(name || self.name, @children)
    mirah.quote do
      def initialize(position:Position, `@children`)
        self.position = position
        `@constructor`
      end
      def initialize(`@children`)
        `@constructor`
      end
      def replaceChild(oldChild:Node, newChild:Node):Node
        if oldChild == newChild
          return newChild
        end
        clone = childAdded(newChild)
        `@replaceNodeList`
        raise IllegalArgumentException, "No child #{oldChild}"
        return Node(nil)
      end
      def removeChild(child:Node)
        `@removeNodeList`
        raise IllegalArgumentException, "No child #{child}"
      end
      def initCopy:void
        super
        `@cloneNodeList`
      end
    end
  end

  def addGetters(name:String, type:String, node:boolean)
    if node
      pre_set = mirah.quote do
        if value == @`name`
          return
        end
        childRemoved(@`name`)
        clone = childAdded(value)
        value = `mirah.cast(type, 'clone')`
      end
    else
      pre_set = NodeList.new
    end
    mirah.quote do
      def `"#{name}"`: `type`
        @`name`
      end
      def `"#{name}_set"`(value: `type`):void
        `pre_set`
        @`name` = value
      end
    end
  end

  def child(name:String, type:String, node:boolean)
    setter = "#{name}_set"
    @constructor.add(mirah.quote do
      self.`setter`(`name`)
    end)
    @children.add([SimpleString.new(name), type])
    @replaceNodeList.add(mirah.quote do
      if self.`name` == oldChild
        self.`setter`(`mirah.cast(type, 'clone')`)
        clone.setOriginalNode(oldChild)
        return clone
      end
    end)
    @removeNodeList.add(mirah.quote do
      if self.`name` == child
        self.`setter`(nil)
        return
      end
    end)
    clone_call = mirah.quote {childAdded(Node(self.`name`.clone))}
    @cloneNodeList.add(mirah.quote do
      if self.`name`
        @`name` = `mirah.cast(type, clone_call)`
      end
    end)
    addGetters(name, type, node)
  end

  def child_list(name:String, type:String)
    list_type = "#{type}List"
    setter = "#{name}_set"
    @constructor.add(mirah.quote do
      self.`setter`(`list_type`.new(position, `name`))
    end)
    size_name = "#{name}_size"
    @children.add([SimpleString.new(name), 'java.util.List'])
    clone_call = mirah.quote {childAdded(Node(self.`name`.clone))}
    @cloneNodeList.add(mirah.quote do
      if self.`name`
        @`name` = `mirah.cast(list_type, clone_call)`
      end
    end)
    mirah.quote do
      `addGetters(name, list_type, true)`

      def `name`(i:int): `type`
        node = @`name`.get(i)
        `mirah.cast(type, 'node')`
      end
      def `size_name`:int
        return @`name`.size if @`name`
        0
      end
    end
  end
end

interface TypeMapper do
  def entry(name:String, type:String):Node; end
end

class NodeMeta < MetaTool
  def initialize(mirah:Compiler)
    super(mirah)
    @nodes = HashMap.new
    @visitors = VisitorState.new(mirah)
  end

  def init_visitor(call:CallSite):Node
    @visitors.init_visitor(call)
    nil
  end

  def init_node(call:CallSite)
    node = NodeState.new(mirah, call, @visitors)
    @nodes[node.name] = node
    node.init_node(call.block)
  end

  def init_list(type:Identifier)
    node = ListNodeState.new(mirah, type, @visitors)
    @nodes[node.name] = node
    node.init_list(type)
  end

  def init_literal(type:Identifier)
    node = NodeState.new(mirah, type, @visitors)
    @nodes[node.name] = node
    node.init_literal(type)
  end

  def init_subclass(parent:Identifier)
    node = NodeState.new(mirah, parent, @visitors)
    parent_state = NodeState(@nodes.get(parent.identifier))
    node.init_subclass(parent_state)
  end

  def child(hash:Hash)
    state = NodeState(@nodes[enclosing_class(hash).name.identifier])
    NodeMeta.type_map_each(NodeList.new, hash) do |name, type|
      state.child(name, type, true)
    end
  end

  def child_list(hash:Hash)
    state = NodeState(@nodes[enclosing_class(hash).name.identifier])
    NodeMeta.type_map_each(NodeList.new, hash) do |name, type|
      state.child_list(name, type)
    end
  end

  def add_constructor(name:Identifier)
    state = NodeState(@nodes[enclosing_class(name).name.identifier])
    state.addConstructor(name.identifier)
  end

  def self.initialize:void
    @@instances = Collections.synchronizedMap(WeakHashMap.new)
  end

  def self.get(mirah:Compiler)
    instance = @@instances[mirah]
    if (instance.nil?)
      instance = self.new(mirah)
      @@instances[mirah] = instance
    end
    NodeMeta(instance)
  end

  def self.type_map_each(body:NodeList, hash:Hash, mapper:TypeMapper):NodeList
    body = body
    hash.size.times do |i|
      entry = hash.get(i)
      name = Identifier(entry.key).identifier
      type = Identifier(entry.value).identifier
      body.add(mapper.entry(name, type))
    end
    body
  end

  def self.init_visitor(mirah:Compiler, call:CallSite):Node
    NodeMeta.get(mirah).init_visitor(call)
  end

  def self.init_node(mirah:Compiler, call:CallSite):Node
    NodeMeta.get(mirah).init_node(call)
  end

  def self.init_list(mirah:Compiler, type:Identifier):Node
    NodeMeta.get(mirah).init_list(type)
  end
  def self.init_literal(mirah:Compiler, type:Identifier):Node
    NodeMeta.get(mirah).init_literal(type)
  end
  def self.init_subclass(mirah:Compiler, parent:Identifier)
    NodeMeta.get(mirah).init_subclass(parent)
  end
  def self.child(mirah:Compiler, hash:Hash)
    NodeMeta.get(mirah).child(hash)
  end
  def self.child_list(mirah:Compiler, hash:Hash)
    NodeMeta.get(mirah).child_list(hash)
  end
  def self.add_constructor(mirah:Compiler, name:Identifier)
    NodeMeta.get(mirah).add_constructor(name)
  end
end