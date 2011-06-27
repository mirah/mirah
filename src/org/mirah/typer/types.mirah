package org.mirah.typer
import java.util.*
import mirah.lang.ast.*

class SpecialType; implements ResolvedType, TypeFuture
  def initialize(name:String)
    @name = name
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
end

class UnreachableType < SpecialType
  def initialize
    super(":unreachable")
  end
  def widen(other)
    other
  end
end

class ErrorType < SpecialType
  def initialize(message:List)
    super(":error")
    @message = message
  end
  def message:List
    @message
  end
end

class BlockType < SpecialType
  def initialize
    super(":block")
  end
end

class InlineCode < SpecialType
  def initialize(node:Node)
    super(:inline)
    @node = node
  end
  def node
    @node
  end
end

interface TypeSystem do
  def getNullType:TypeFuture; end
  def getVoidType:TypeFuture; end
  def getBaseExceptionType:TypeFuture; end
  def getDefaultExceptionType:TypeFuture; end
  def getRegexType:TypeFuture; end
  def getStringType:TypeFuture; end
  def getBooleanType:TypeFuture; end
  def getFixnumType(value:long):TypeFuture; end
  def getCharType(value:int):TypeFuture; end
  def getFloatType(value:double):TypeFuture; end

  def getMetaType(type:ResolvedType):ResolvedType; end
  def getArrayType(componentType:ResolvedType):ResolvedType; end

  def getMetaType(type:TypeFuture):TypeFuture; end
  def getArrayType(componentType:TypeFuture):TypeFuture; end

  def get(type:TypeRef):TypeFuture; end
  def getMethodType(target:TypeFuture, name:String, argTypes:List):TypeFuture; end
  def getMethodDefType(target:TypeFuture, name:String, argTypes:List):AssignableTypeFuture; end
  def getFieldType(target:TypeFuture, name:String):AssignableTypeFuture; end
  def getLocalType(scope:Scope, name:String):AssignableTypeFuture; end
  def getArrayType(componentType:TypeFuture):TypeFuture; end
  def getMainType(scope:Scope, script:Script):TypeFuture; end
  def getSuperClass(type:TypeFuture):TypeFuture; end

  def defineType(scope:Scope, node:ClassDefinition, name:String, superclass:TypeFuture, interfaces:List):TypeFuture; end
end