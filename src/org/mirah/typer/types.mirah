package org.mirah.typer
import java.util.*
import mirah.lang.ast.*

class SpecialType; implements ResolvedType, TypeFuture
  def initialize(name:String)
    @name = name
  end
  def isInterface
    false
  end
  def isResolved
    true
  end
  def resolve
    self
  end
  def name
    @name
  end
  def widen(other)
    self
  end
  def assignableFrom(other)
    true
  end
  def onUpdate(l)
    l.updated(self, self)
  end
  def equals(other:Object)
    other.kind_of?(ResolvedType) && ResolvedType(other).name == @name
  end
  def hashCode
    name.hashCode
  end
  def toString
    "<#{getClass.getSimpleName}: #{name}>"
  end
  def isMeta; false; end
  def isError; ":error".equals(name); end
  def matchesAnything; false; end
end

class UnreachableType < SpecialType
  def initialize
    super(":unreachable")
  end
  def widen(other)
    other
  end
  def matchesAnything; true; end
end

class ErrorType < SpecialType
  def initialize(message:List)
    super(":error")
    @message = checkMessage(message)
  end
  def message:List
    @message
  end
  def matchesAnything; true; end
  def toString:String
    "<Error: #{message}>"
  end
  def equals(other:Object)
    other.kind_of?(ErrorType) && message.equals(ErrorType(other).message)
  end
  def hashCode
    message.hashCode
  end
  private
  def checkMessage(message:List)
    new_message = ArrayList.new(message.size)
    message.each do |_pair|
      pair = List(_pair)
      text = String(pair.get(0))
      position = pair.size > 1 ? Position(pair.get(1)) : nil
      new_pair = ArrayList.new(2)
      new_pair.add(text)
      new_pair.add(position)
      new_message.add(new_pair)
    end
    new_message
  end
end

class BlockType < SpecialType
  def initialize
    super(":block")
  end
end

interface NodeBuilder do
  def buildNode(node:Node, typer:Typer):Node; end
end

class InlineCode < SpecialType
  def initialize(node:Node)
    super(':inline')
    @node = node
  end
  def initialize(block:NodeBuilder)
    super(':inline')
    @block = block
  end
  def expand(node:Node, typer:Typer)
    if @block
      @block.buildNode(node, typer)
    else
      @node
    end
  end
end

class MethodType
  implements ResolvedType
  # TODO should this include the defining class?
  def initialize(name:String, parameterTypes:List, returnType:ResolvedType, isVararg:boolean)
    @name = name
    @parameterTypes = parameterTypes
    @returnType = returnType
    @isVararg = isVararg
    raise IllegalArgumentException unless parameterTypes.all? {|p| p.kind_of?(ResolvedType)}
    raise IllegalArgumentException if parameterTypes.any? {|p| p.kind_of?(BlockType)}
  end

  def name
    @name
  end

  def parameterTypes:List
    @parameterTypes
  end

  def returnType:ResolvedType
    @returnType
  end

  def isVararg:boolean
    @isVararg
  end

  def widen(other:ResolvedType):ResolvedType
    return self if other == self
    raise IllegalArgumentException
  end
  def assignableFrom(other:ResolvedType):boolean
    other == self
  end
  def isMeta:boolean
    false
  end
  def isInterface:boolean
    false
  end
  def isError:boolean
    false
  end
  def matchesAnything:boolean
    false  
  end
end

interface TypeSystem do
  def getNullType:TypeFuture; end
  def getVoidType:TypeFuture; end
  def getImplicitNilType:TypeFuture; end
  def getBaseExceptionType:TypeFuture; end
  def getDefaultExceptionType:TypeFuture; end
  def getRegexType:TypeFuture; end
  def getStringType:TypeFuture; end
  def getHashType:TypeFuture; end
  def getBooleanType:TypeFuture; end
  def getFixnumType(value:long):TypeFuture; end
  def getCharType(value:int):TypeFuture; end
  def getFloatType(value:double):TypeFuture; end

  def getMetaType(type:ResolvedType):ResolvedType; end
  def getArrayType(componentType:ResolvedType):ResolvedType; end

  def getMetaType(type:TypeFuture):TypeFuture; end
  def getArrayType(componentType:TypeFuture):TypeFuture; end
  def getArrayLiteralType(componentType:TypeFuture):TypeFuture; end

  def get(scope:Scope, type:TypeRef):TypeFuture; end
  def getMethodType(call:CallFuture):TypeFuture; end  # Must resolve to MethodType
  #def getMethodType(target:ResolvedType, name:String, argTypes:List, position:Position):TypeFuture; end
  def getMethodDefType(target:TypeFuture, name:String, argTypes:List):MethodFuture; end
  def getFieldType(target:TypeFuture, name:String, position:Position):AssignableTypeFuture; end
  def getLocalType(scope:Scope, name:String, position:Position):AssignableTypeFuture; end
  def getMainType(scope:Scope, script:Script):TypeFuture; end
  def getSuperClass(type:TypeFuture):TypeFuture; end

  def defineType(scope:Scope, node:ClassDefinition, name:String, superclass:TypeFuture, interfaces:List):TypeFuture; end
  def addDefaultImports(scope:Scope):void; end
  
  # Returns a List of MethodTypes of the abstract methods that a closure should implement.
  def getAbstractMethods(type:ResolvedType):List; end
end