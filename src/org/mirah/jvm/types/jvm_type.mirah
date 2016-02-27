package org.mirah.jvm.types

import org.mirah.typer.ResolvedType
import org.mirah.typer.TypeFuture
import org.objectweb.asm.Type
import java.util.List
import java.util.Set

interface JVMMember
  def declaringClass:JVMType; end
  def name:String; end
  def argumentTypes:List; end
  def returnType:JVMType; end
  def accept(visitor:MemberVisitor, expression:boolean):void; end
  def kind:MemberKind; end
  def isVararg:boolean; end
  def isAbstract:boolean; end
end

interface JVMMethod < JVMMember
end

interface JVMField < JVMMember
end

interface GenericMethod < JVMMethod
  def genericReturnType:JVMType; end
end

interface JVMType < ResolvedType
  def superclass:JVMType; end
  def getAsmType:Type; end
  def flags:int; end

  def interfaces:TypeFuture[]; end

  def retention:String; end

  def getComponentType:JVMType; end

  def hasStaticField(name:String):boolean; end

  def box:JVMType; end
  def unbox:JVMType; end

  # Find the JVMMethod for a method call.
  # TODO: We've already looked this up during inference, it'd be better if
  # we could save that instead of doing the full search again.
  def getMethod(name:String, params:List):JVMMethod; end

  def getDeclaredFields:JVMField[]; end
  def getDeclaredField(name:String):JVMField; end
end

interface CallType < JVMType
  def member:JVMMethod; end
end
