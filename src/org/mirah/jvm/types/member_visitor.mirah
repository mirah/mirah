package org.mirah.jvm.types

interface MemberVisitor
  def visitMath(method:JVMMethod, expression:boolean):void; end
  def visitMethodCall(method:JVMMethod, expression:boolean):void; end
  def visitStaticMethodCall(method:JVMMethod, expression:boolean):void; end
  def visitFieldAccess(method:JVMMethod, expression:boolean):void; end
  def visitStaticFieldAccess(method:JVMMethod, expression:boolean):void; end
  def visitFieldAssign(method:JVMMethod, expression:boolean):void; end
  def visitStaticFieldAssign(method:JVMMethod, expression:boolean):void; end
end