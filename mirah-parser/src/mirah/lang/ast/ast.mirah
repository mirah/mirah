package mirahparser.lang.ast

import java.io.InputStream
import java.io.Serializable
import java.util.ArrayList
import java.util.LinkedList
import java.util.List
import java.util.Iterator
import org.mirahparser.ast.NodeMeta

interface CodeSource do
  def name:String; end
  def initialLine:int; end
  def initialColumn:int; end
  def contents:String; end
  def substring(start:int, end:int):String; end
end

interface Position do
  def source:CodeSource; end
  def startChar:int; end
  def startLine:int; end
  def startColumn:int; end
  def endChar:int; end
  def endLine:int; end
  def endColumn:int; end
  def add(other:Position):Position; end
  macro def +(other) quote { `@call.target`.add(`other`) } end
end

interface CloneListener do
  def wasCloned(original:Node, clone:Node):void; end
end

interface Node < Cloneable do
  def position:Position; end
  def parent:Node; end
  def setParent(parent:Node):void; end  # This should only be called by NodeImpl!
  def originalNode:Node; end
  def setOriginalNode(node:Node):void; end  # Probably don't want to call this either.

  # Returns the new child, which may be a clone.
  def replaceChild(child:Node, newChild:Node):Node; end

  def removeChild(child:Node):void; end
  def accept(visitor:NodeVisitor, arg:Object):Object; end
  def whenCloned(listener:CloneListener):void; end

  def findAncestor(type:Class):Node; end
  def findAncestor(filter:NodeFilter):Node; end
  def findChild(filter:NodeFilter):List; end
  def findChildren(filter:NodeFilter):List; end
  def findChildren(filter:NodeFilter, list:List):List; end
  def findDescendant(filter:NodeFilter):Node; end
  def findDescendants(filter:NodeFilter):List; end
  def findDescendants(filter:NodeFilter, list:List):List; end
  def clone:Object; end
end

interface Assignment < Node do
  def value:Node; end
  def value=(value:Node):void; end
end

interface Identifier < Node do
  def identifier:String; end
end

interface TypeName < Node do
  def typeref:TypeRef; end
end

interface Named < Node do
  def name:Identifier; end
end

interface Annotated < Node do
  def annotations: AnnotationList; end
  # macro def annotation(name)
  #   quote do
  #     annotations.findChild {|c| `name`.equals(c.name.identifier) }
  #   end
  # end
end

# Should this go somewhere else?
# Should this support multi-dimensional arrays?
interface TypeRef < TypeName do
  def name:String; end
  def isArray:boolean; end
  def isStatic:boolean; end
  macro def array?
    quote { isArray }
  end
  macro def static?
    quote { isStatic }
  end
end

interface NodeVisitor do
  macro def self.init_visitor; NodeMeta.init_visitor(@mirah, @call); end
  init_visitor
end

interface NodeFilter do
  def matchesNode(node:Node):boolean; end
end

interface NodeSetter do
  def set(node:Node):void; end
end

class NodeRef
  def initialize(value:Node, setter:NodeSetter)
    @value = value
    @setter = setter
  end

  def get:Node
    @value
  end

  def replaceWith(newValue:Node):void
    @setter.set(newValue)
    newValue.setOriginalNode(@value) if newValue
    @value = newValue
  end
end

class NodeImpl implements Node
  class << self
    macro def init_node(&block); NodeMeta.init_node(@mirah, @call); end
    macro def init_node(); NodeMeta.init_node(@mirah, @call); end
    macro def init_list(type:Identifier); NodeMeta.init_list(@mirah, type); end
    macro def init_literal(type:Identifier); NodeMeta.init_literal(@mirah, type); end
    macro def init_subclass(parent:Identifier); NodeMeta.init_subclass(@mirah, parent); end
    macro def child(hash:Hash); NodeMeta.child(@mirah, hash); end
    macro def child_list(hash:Hash); NodeMeta.child_list(@mirah, hash); end
    macro def add_constructor(name:Identifier); NodeMeta.add_constructor(@mirah, name); end
  end

  def accept(visitor:NodeVisitor, arg:Object):Object
    visitor.visitOther(self, arg)
  end
  attr_accessor position: Position
  attr_reader parent: Node
  attr_reader originalNode: Node

  def findAncestor(type:Class):Node
    node = self.as!(Node)
    node = node.parent until node.nil? || type.isInstance(node)
    node
  end

  def findAncestor(filter:NodeFilter):Node
    node = self.as!(Node)
    node = node.parent until node.nil? || filter.matchesNode(node)
    node
  end

  def toString
    name = if self.kind_of?(Named)
      # NB: typesystem can't assume that NodeImpl can be cast to Named right now.
      # So need to cast up to object before casting down. Not sure if it's absolutely necessary.
      ":#{Named(Object(self)).name}"
    else
      ""
    end
    "<#{getClass.getName}#{name}>"
  end

  # Override initCopy instead
  def clone:Object
    cloned = NodeImpl(super)
    cloned.initCopy
    fireWasCloned(cloned)
    cloned
  end

  def setParent(parent:Node)
    @parent = parent
  end

  def findChild(filter:NodeFilter):Node
    finder = DescendentFinder.new(true, true, filter)
    finder.scan(self, nil)
    finder.result
  end

  def findChildren(filter:NodeFilter):List
    finder = DescendentFinder.new(true, false, filter)
    finder.scan(self, nil)
    finder.results
  end

  def findDescendant(filter:NodeFilter):Node
    finder = DescendentFinder.new(false, true, filter)
    finder.scan(self, nil)
    finder.result
  end

  def findDescendants(filter:NodeFilter):List
    finder = DescendentFinder.new(false, false, filter)
    finder.scan(self, nil)
    finder.results
  end

  def setOriginalNode(node:Node):void
    @originalNode = node
  end

  def whenCloned(listener:CloneListener)
    @clone_listeners.add(listener)
  end

# protected
  def initialize
    @clone_listeners = LinkedList.new
  end
  def initialize(position: Position)
    @clone_listeners = LinkedList.new
    self.position = position
  end

  def childAdded(child:Node):Node
    return child if child.nil?
    if child.parent && child.parent != self
      child = child.clone.as!(Node)
    end
    child.setParent(self)
    child
  end

  def childRemoved(child:Node):Node
    return nil if child.nil?
    child.setParent(nil)
    child
  end

  def fireWasCloned(clone:Node):void
    @clone_listeners.each do |listener|
      CloneListener(listener).wasCloned(self, clone)
    end
  end

  # Should only be called during clone.
  def initCopy:void
    @parent = nil
    @clone_listeners = LinkedList.new
  end
end

 class DescendentFinder < NodeScanner

   def initialize(children_only:boolean, only_one:boolean, filter:NodeFilter)
     @results = ArrayList.new
     @children = children_only
     @only_one = only_one
     @filter = filter
   end

   def enterDefault(node: Node, arg:Object): boolean
     return false if @results.size == 1 && @only_one
     if @filter.matchesNode(node)
       @results.add(node)
       return false if @only_one
     end
     return !@children
   end

   def results:List
     @results
   end

   def result:Node
     if @results.size == 0
       nil
     else
       @results.get(0).as!(Node)
     end
   end
 end

class ErrorNode < NodeImpl
  init_node
end

class TypeRefImpl < NodeImpl implements TypeRef, TypeName
  init_node
  attr_accessor name: String, isArray: 'boolean', isStatic: 'boolean'

  def initialize(name:String, isArray=false, isStatic=false, position:Position=nil)
    super(position)
    @name = name
    @isArray = isArray
    @isStatic = isStatic
  end

  def typeref:TypeRef
    TypeRef(self)
  end
end

class StringCodeSource implements CodeSource
  def initialize(name:String, code:String)
    @name = name
    @code = code
    @startLine = 1
    @startCol = 1
  end
  def initialize(name:String, code:String, startLine:int, startCol:int)
    @name = name
    @code = code
    @startLine = startLine
    @startCol = startCol
  end
  def name:String; @name; end
  def contents; @code; end
  def substring(startPos, endPos); @code.substring(startPos, endPos); end
  def initialLine; @startLine; end
  def initialColumn; @startCol; end

  def toString
    "#{@name} #{@code} #{@startLine}:#{@startCol}"
  end
end

class StreamCodeSource < StringCodeSource
  def initialize(filename:String)
    super(filename, StreamCodeSource.readToString(
        java::io::FileInputStream.new(filename)))
  end
  def initialize(name:String, stream:InputStream)
    super(name, StreamCodeSource.readToString(stream))
  end
  def self.readToString(stream:InputStream):String
    reader = java::io::BufferedReader.new(java::io::InputStreamReader.new(stream))
    buffer = char[8192]
    builder = StringBuilder.new
    while (read = reader.read(buffer, 0, buffer.length)) > 0
      builder.append(buffer, 0, read);
    end
    return builder.toString
  end
end

class PositionImpl implements Position
  def initialize(source:CodeSource, startChar:int, startLine:int, startColumn:int,
                 endChar:int, endLine:int, endColumn: int)
    @source = source
    @startChar = startChar
    @startLine = startLine
    @startColumn = startColumn
    @endChar = endChar
    @endLine = endLine
    @endColumn = endColumn
  end
  def toString
    "source:#{source && source.name} start:#{startLine} #{startColumn} end: #{endLine} #{endColumn}"
  end
  def source:CodeSource; @source; end
  def startChar:int; @startChar; end
  def startLine:int; @startLine; end
  def startColumn:int; @startColumn; end
  def endChar:int; @endChar; end
  def endLine:int; @endLine; end
  def endColumn:int; @endColumn; end
  def add(other:Position):Position
    return self unless other
    if @source.equals(other.source)
      Position(PositionImpl.new(
          @source, Math.min(@startChar, other.startChar),
          Math.min(@startLine, other.startLine),
          Math.min(@startColumn, other.startColumn),
          Math.max(@endChar, other.endChar),
          Math.max(@endLine, other.endLine),
          Math.max(@endColumn, other.endColumn)))
    else
      Position(self)
    end
  end
  def self.add(a:Position, b:Position):Position
    if a && b
      a.add(b)
    elsif a
      a
    else
      b
    end
  end
end