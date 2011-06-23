package mirahparser.lang.ast

import java.io.Serializable
import java.util.ArrayList
import java.util.List
import java.util.Iterator
import org.mirahparser.ast.NodeMeta

interface Position do
  def filename:string; end
  def startLine:int; end
  def startColumn:int; end
  def endLine:int; end
  def endColumn:int; end
  def add(other:Position):Position; end
  macro def +(other) quote { add(`other`) } end
end

interface Node do
  def position:Position; end
  def parent:Node; end
  def setParent(parent:Node):void; end  # This should only be called by NodeImpl!
  def originalNode:Node; end
  def setOriginalNode(node:Node):void; end  # Probably don't want to call this either.
  def replaceChild(child:Node, newChild:Node):void; end
  def accept(visitor:NodeVisitor, arg:Object):Object; end

  def findAncestor(type:java::lang::Class):Node; end
  def findAncestor(filter:NodeFilter):Node; end
  def findChild(filter:NodeFilter):List; end
  def findChildren(filter:NodeFilter):List; end
  def findChildren(filter:NodeFilter, list:List):List; end
  def findDescendant(filter:NodeFilter):Node; end
  def findDescendants(filter:NodeFilter):List; end
  def findDescendants(filter:NodeFilter, list:List):List; end
end

interface Assignment < Node do
  def value=(value:Node); end
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
  def annotations:AnnotationList; end
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
  macro def init_visitor; NodeMeta.init_visitor(@mirah, @call); end
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

class NodeImpl
  implements Node
  macro def init_node(&block); NodeMeta.init_node(@mirah, @call); end
  macro def init_node(); NodeMeta.init_node(@mirah, @call); end
  macro def init_list(type); NodeMeta.init_list(@mirah, type); end
  macro def init_literal(type); NodeMeta.init_literal(@mirah, type); end
  macro def init_subclass(parent); NodeMeta.init_subclass(@mirah, parent); end
  macro def attr_reader(hash); NodeMeta.attr_reader(@mirah, hash); end
  macro def attr_writer(hash); NodeMeta.attr_writer(@mirah, hash); end
  macro def attr_accessor(hash); NodeMeta.attr_accessor(@mirah, hash); end
  macro def child(hash); NodeMeta.child(@mirah, hash); end
  macro def child_list(hash); NodeMeta.child_list(@mirah, hash); end
  macro def add_constructor(name); NodeMeta.add_constructor(@mirah, name); end

  def accept(visitor:NodeVisitor, arg:Object):Object
    visitor.visitOther(self, arg)
  end
  attr_accessor position: Position
  attr_reader parent: Node
  attr_reader originalNode: Node

  def findAncestor(type:java::lang::Class):Node
    node = Node(self)
    node = node.parent until node.nil? || node.kind_of?(type)
    node
  end

  def findAncestor(filter:NodeFilter):Node
    node = Node(self)
    node = node.parent until node.nil? || filter.matchesNode(node)
    node
  end

  def toString
    name = if self.kind_of?(Named)
      ":#{Named(self).name}"
    else
      ""
    end
    "<#{getClass.getName}#{name}>"
  end

  def setParent(parent:Node)
    @parent = parent
  end

  # def findChild(filter:NodeFilter):Node
  #   finder = DescendentFinder.new(true, true, filter)
  #   finder.scan(self, nil)
  #   finder.result
  # end
  # 
  # def findChildren(filter:NodeFilter):List
  #   finder = DescendentFinder.new(true, false, filter)
  #   finder.scan(self, nil)
  #   finder.results
  # end
  # 
  # def findDescendant(filter:NodeFilter):Node
  #   finder = DescendentFinder.new(false, true, filter)
  #   finder.scan(self, nil)
  #   finder.result
  # end
  # 
  # def findDescendants(filter:NodeFilter):List
  #   finder = DescendentFinder.new(false, false, filter)
  #   finder.scan(self, nil)
  #   finder.results
  # end

 protected
  def initialize; end
  def initialize(position: Position)
    self.position = position
  end

  def childAdded(child:Node):Node
    return nil if child.nil?
    if child.parent
      # Should we remove it from the parent? Duplicate it?
      raise IllegalArgumentException, "Node already has a parent"
    end
    child.setParent(self)
    child
  end

  def childRemoved(child:Node):Node
    return nil if child.nil?
    child.setParent(nil)
    child
  end

  private
  attr_writer originalNode: Node
  # TODO clone
end

# class DescendentFinder < NodeScanner
#   def initialize(children_only:boolean, only_one:boolean, filter:NodeFilter)
#     @results = ArrayList.new
#     @children = children_only
#     @only_one = only_one
#     @filter = filter
#   end
# 
#   def enterDefault(node:Node, arg:Object):boolean
#     return false if @results.size == 1 && @only_one
#     if @filter.matchesNode(node)
#       @results.add(node)
#       return false if @only_one
#     end
#     return !@children
#   end
# 
#   def results:List
#     @results
#   end
# 
#   def result:Node
#     if @results.size == 0
#       nil
#     else
#       Node(@results.get(0))
#     end
#   end
# end

class ErrorNode < NodeImpl
  init_node
end

class TypeRefImpl < NodeImpl; implements TypeRef, TypeName
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

class PositionImpl; implements Position
  def initialize(filename:String, startLine:int, startColumn:int, endLine:int, endColumn: int)
    @filename = filename
    @startLine = startLine
    @startColumn = startColumn
    @endLine = endLine
    @endColumn = endColumn
  end
  def filename:string; @filename; end
  def startLine:int; @startLine; end
  def startColumn:int; @startColumn; end
  def endLine:int; @endLine; end
  def endColumn:int; @endColumn; end
  def add(other:Position):Position
    if @filename.equals(other.filename)
      Position(PositionImpl.new(
          @filename, Math.min(@startLine, other.startLine), Math.min(@startColumn, other.startColumn),
          Math.max(@endLine, other.endLine), Math.max(@endColumn, other.endColumn)))
    else
      Position(self)
    end
  end
end