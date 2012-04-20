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

import duby.lang.compiler.*
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
    @ivisitor = mirah.body
    @simple = Body(mirah.defineClass('SimpleNodeVisitor', 'java.lang.Object', ['NodeVisitor']).body)
    @scanner = Body(mirah.defineClass('NodeScanner', 'java.lang.Object', ['NodeVisitor']).body)
  end

  def init_visitor(call:Call)
    Body(enclosing_class(call).body) << @ivisitor
    simple << mirah.quote do
      def defaultNode(node:Node, arg:Object):Object
        nil
      end
    end
    scanner << mirah.quote do
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
    end
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
    ivisitor << mirah.quote do
      def `"visit#{name}"`(node: `type`, arg:Object):Object; end
    end
    simple << mirah.quote do
      def `"visit#{name}"`(node: `type`, arg:Object):Object
        defaultNode(node, arg)
      end
    end
    addScanner(scanner, type, name, scanChildren)
  end

  def addScanner(scanner:Body, type:String, name:String, scanChildren:Node)
    scanner << mirah.quote do
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
  end

  def addNode(type:String, children:List, name:String=nil)
    childScanner = mirah.body
    if children
      children.each do |c|
        child_name = List(c).get(0)
        child_type = String(List(c).get(1))
        childScanner << mirah.quote do
          scan(node.`child_name`, arg)
        end
      end
    end
    addNode(type, name, childScanner)
  end

  def ivisitor:Body
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
    @klass.name
  end
end

class ListNodeState < BaseNodeState
  def initialize(mirah:Compiler, type:Node, visitors:VisitorState)
    super(mirah, type)
    @visitors = visitors
    raise NullPointerException if visitors.nil?
  end

  def init_list(type:Node)
    type_name = type.string_value
    visitor_method = "visit#{name}"
    @visitors.addList(name)
    iterator_name = "#{name}Iterator"
    iterator = Body(mirah.defineClass(iterator_name, 'java.lang.Object', ['java.util.ListIterator']).body)
    iterator << mirah.quote do
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
    mirah.quote do
      implements Iterable
      import java.util.Iterator
      import java.util.ListIterator

      def initialize()
        @children = java::util::ArrayList.new
      end

      def initialize(position:Position)
        self.position = position
        @children = java::util::ArrayList.new
      end

      def initialize(children:java::util::List)
        if children
          startPosition = nil
          endPosition = nil
          @children = java::util::ArrayList.new(children.size)
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
          @children = java::util::ArrayList.new
        end
        nil
      end

      def initialize(position:Position, children:java::util::List)
        self.position = position
        if children
          @children = java::util::ArrayList.new(children.size)
          children.each {|node:Node| @children.add(childAdded(Node(node)))}
        else
          @children = java::util::ArrayList.new
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

      public
      def iterator
        listIterator(0)
      end

      def listIterator(start:int = 0):java::util::ListIterator
        `iterator_name`.new(self, start)
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
    @constructor = mirah.body
    @replaceBody = mirah.body
    @removeBody = mirah.body
    @cloneBody = mirah.body
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
      extra_setup = mirah.body
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

  def init_literal(type:Node)
    name = mirah.string(self.name)
    mirah.quote do
      `init_node(nil)`
      `child('value', type.string_value, false)`
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
        `@replaceBody`
        raise IllegalArgumentException, "No child #{oldChild}"
        return Node(null)
      end
      def removeChild(child:Node)
        `@removeBody`
        raise IllegalArgumentException, "No child #{child}"
      end
      def initCopy:void
        super
        `@cloneBody`
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
      pre_set = mirah.body
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
    @constructor << mirah.quote do
      self.`setter`(`name`)
    end
    @children.add([name, type])
    @replaceBody << mirah.quote do
      if self.`name` == oldChild
        self.`setter`(`mirah.cast(type, 'clone')`)
        clone.setOriginalNode(oldChild)
        return clone
      end
    end
    @removeBody << mirah.quote do
      if self.`name` == child
        self.`setter`(nil)
        return
      end
    end
    clone_call = mirah.quote {childAdded(Node(self.`name`.clone))}
    @cloneBody << mirah.quote do
      if self.`name`
        @`name` = `mirah.cast(type, clone_call)`
      end
    end
    addGetters(name, type, node)
  end

  def child_list(name:String, type:String)
    list_type = "#{type}List"
    setter = "#{name}_set"
    @constructor << mirah.quote do
      self.`setter`(`list_type`.new(position, `name`))
    end
    size_name = "#{name}_size"
    @children.add([name, 'java.util.List'])
    clone_call = mirah.quote {childAdded(Node(self.`name`.clone))}
    @cloneBody << mirah.quote do
      if self.`name`
        @`name` = `mirah.cast(list_type, clone_call)`
      end
    end
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

  def init_visitor(call:Call)
    @visitors.init_visitor(call)
    nil
  end

  def init_node(call:Call)
    node = NodeState.new(mirah, call, @visitors)
    @nodes[node.name] = node
    node.init_node(call.block)
  end

  def init_list(type:Node)
    node = ListNodeState.new(mirah, type, @visitors)
    @nodes[node.name] = node
    node.init_list(type)
  end

  def init_literal(type:Node)
    node = NodeState.new(mirah, type, @visitors)
    @nodes[node.name] = node
    node.init_literal(type)
  end

  def init_subclass(parent:Node)
    node = NodeState.new(mirah, parent, @visitors)
    parent_state = NodeState(@nodes.get(parent.string_value))
    node.init_subclass(parent_state)
  end

  def child(hash:Node)
    state = NodeState(@nodes[enclosing_class(hash).name])
    NodeMeta.type_map_each(mirah.body, hash) do |name, type|
      state.child(name, type, true)
    end
  end

  def child_list(hash:Node)
    state = NodeState(@nodes[enclosing_class(hash).name])
    NodeMeta.type_map_each(mirah.body, hash) do |name, type|
      state.child_list(name, type)
    end
  end

  def add_constructor(name:Node)
    state = NodeState(@nodes[enclosing_class(name).name])
    state.addConstructor(name.string_value)
  end

  def self.initialize:void
    @@instances = Collections.synchronizedMap(WeakHashMap.new)
  end

  def self.get(mirah:Compiler)
    instance = @@instances[mirah]
    if (instance.nil?)
      instance = NodeMeta.new(mirah)
      @@instances[mirah] = instance
    end
    NodeMeta(instance)
  end

  def self.attr_reader(mirah:Compiler, hash:Node):Body
    type_map_each(mirah.body, hash) do |name, type|
      mirah.quote do
        def `name`: `type`
          @`name`
        end
      end
    end
  end

  def self.attr_writer(mirah:Compiler, hash:Node):Body
    type_map_each(mirah.body, hash) do |name, type|
      setter_name = "#{name}_set"
      mirah.quote do
        def `setter_name`(value: `type`):void
          @`name` = value
        end
      end
    end
  end

  def self.attr_accessor(mirah:Compiler, hash:Node):Node
    result = attr_reader(mirah, hash)
    result << attr_writer(mirah, hash)
    result
  end

  def self.type_map_each(body:Body, hash:Node, mapper:TypeMapper):Body
    body = body
    children = hash.child_nodes
    while children.size == 1
      children = Node(children.get(0)).child_nodes
    end
    # UGH. We get the expanded new_hash macro.
    children.each do |s|
      if s.kind_of?(Call)
        call = Call(s)
        if 'put'.equals(call.name)
          name = Node(call.arguments.get(0))
          type = Node(call.arguments.get(1))
          body << mapper.entry(name.string_value, type.string_value)
        end
      end
      nil
    end
    body
  end

  def self.init_visitor(mirah:Compiler, call:Call):Node
    NodeMeta.get(mirah).init_visitor(call)
  end

  def self.init_node(mirah:Compiler, call:Call):Node
    NodeMeta.get(mirah).init_node(call)
  end

  def self.init_list(mirah:Compiler, type:Node):Node
    NodeMeta.get(mirah).init_list(type)
  end
  def self.init_literal(mirah:Compiler, type:Node):Node
    NodeMeta.get(mirah).init_literal(type)
  end
  def self.init_subclass(mirah:Compiler, parent:Node)
    NodeMeta.get(mirah).init_subclass(parent)
  end
  def self.child(mirah:Compiler, hash:Node)
    NodeMeta.get(mirah).child(hash)
  end
  def self.child_list(mirah:Compiler, hash:Node)
    NodeMeta.get(mirah).child_list(hash)
  end
  def self.add_constructor(mirah:Compiler, name:Node)
    NodeMeta.get(mirah).add_constructor(name)
  end
end