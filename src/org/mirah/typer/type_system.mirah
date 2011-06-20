package org.mirah.typer
import java.util.*
import mirah.lang.ast.*

interface ResolvedType do
  def widen(other:ResolvedType):ResolvedType; end
  def assignableFrom(other:ResolvedType):boolean; end
  def name:String; end
  def isMeta:boolean; end
end

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
    @message = list
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
  def getNullType:ResolvedType; end
  def getVoidType:ResolvedType; end
  def getFixnumType(value:long):ResolvedType; end
  def getFloatType(value:double):ResolvedType; end
  def getBaseExceptionType:ResolvedType; end
  def getDefaultExceptionType:ResolvedType; end
  def getMetaType(type:ResolvedType):ResolvedType; end
  def getArrayType(componentType:ResolvedType):ResolvedType; end
end