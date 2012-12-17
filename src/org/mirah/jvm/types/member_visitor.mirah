package org.mirah.jvm.types

interface MemberVisitor
  def visitMath(op:int, type:JVMType, expression:boolean); end
end