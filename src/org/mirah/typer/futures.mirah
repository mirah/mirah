# TODO: This code is thread hostile.
package org.mirah.typer
import java.util.*
import java.util.logging.Logger
import java.util.logging.Level
import mirah.lang.ast.*

interface TypeListener do
  def updated(src:TypeFuture, value:ResolvedType):void; end
end

interface ResolvedType do
  def widen(other:ResolvedType):ResolvedType; end
  def assignableFrom(other:ResolvedType):boolean; end
  def name:String; end
  def isMeta:boolean; end
  def isBlock:boolean; end
  def isInterface:boolean; end
  def isError:boolean; end
  def matchesAnything:boolean; end
end

interface GenericType do
  def type_parameter_map:HashMap; end
end

interface TypeFuture do
  def isResolved:boolean; end
  
  # Returns the resolved type for this future, or an ErrorType if not yet resolved.
  def resolve:ResolvedType; end
  
  # Add a listener for this future.
  # listener will be called whenever this future resolves to a different type.
  # If the future is already resolved listener will be immediately called.
  def onUpdate(listener:TypeListener):TypeListener; end
  
  def removeListener(listener:TypeListener):void; end
end
