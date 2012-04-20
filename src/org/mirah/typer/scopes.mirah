package org.mirah.typer
import mirah.lang.ast.Node
import java.util.List
import java.util.Map

interface Scope do
  def selfType:TypeFuture; end  # Should this be resolved?
  def selfType=(type:TypeFuture):void; end
  def context:Node; end
  def parent:Scope; end
  def parent=(scope:Scope):void; end
  def shadow(name:String):void; end
  def import(fullname:String, shortname:String); end
  def package:String; end
  def package=(package:String):void; end
  def resetDefaultSelfNode:void; end
  def temp(name:String):String; end
  def imports:Map; end  # Map of short -> long; probably should be reversed.
  def search_packages:List; end
end

interface Scoper do
  def getScope(node:Node):Scope; end
  def addScope(node:Node):Scope; end
  def copyScopeFrom(from:Node, to:Node):void; end
end