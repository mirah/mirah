package org.mirah.jvm.types

interface MemberVisitor
  def visitMath(method:JVMMethod, expression:boolean):void; end
  def visitComparison(method:JVMMethod, expression:boolean):void; end
  def visitMethodCall(method:JVMMethod, expression:boolean):void; end
  def visitStaticMethodCall(method:JVMMethod, expression:boolean):void; end
  def visitFieldAccess(method:JVMMethod, expression:boolean):void; end
  def visitStaticFieldAccess(method:JVMMethod, expression:boolean):void; end
  def visitFieldAssign(method:JVMMethod, expression:boolean):void; end
  def visitStaticFieldAssign(method:JVMMethod, expression:boolean):void; end
  def visitConstructor(method:JVMMethod, expression:boolean):void; end
  def visitStaticInitializer(method:JVMMethod, expression:boolean):void; end
  def visitArrayAccess(method:JVMMethod, expression:boolean):void; end
  def visitArrayAssign(method:JVMMethod, expression:boolean):void; end
  def visitArrayLength(method:JVMMethod, expression:boolean):void; end
  def visitClassLiteral(method:JVMMethod, expression:boolean):void; end
  def visitInstanceof(method:JVMMethod, expression:boolean):void; end
  def visitIsNull(method:JVMMethod, expression:boolean):void; end
end