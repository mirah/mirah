package org.mirah.jvm.types

import org.mirah.typer.ResolvedType
import org.jruby.org.objectweb.asm.Type
import java.util.List

interface JVMMethod
  def declaringClass:JVMType; end
  def name:String; end
  def argumentTypes:List; end
  def returnType:JVMType; end
  def accept(visitor:MemberVisitor, expression:boolean):void; end
end

interface JVMType < ResolvedType
  def superclass:JVMType; end
  def internal_name:String; end
  def class_id:String; end
  def getAsmType:Type; end

  def isPrimitive:boolean; end
  def isEnum:boolean; end

  def isAnnotation:boolean; end
  def retention:String; end
  
  def isArray:boolean; end
  def getComponentType:JVMType; end
  
  def hasStaticField(name:String):boolean; end
  def getMethod(name:String, params:List):JVMMethod; end
end
