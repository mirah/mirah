package org.mirah.typer
import java.util.*
import mirah.lang.ast.*

interface TypeListener do
  def updated(src:TypeFuture, value:ResolvedType):void; end
end

interface TypeFuture do
  def isResolved:boolean; end
  def resolve:ResolvedType; end
  def onUpdate(listener:TypeListener):void; end
end

class BaseTypeFuture; implements TypeFuture
  def initialize(position:Position)
    @position = position
    @listeners = ArrayList.new
  end

  def isResolved
    @resolved != nil
  end

  def inferredType
    @resolved
  end

  def resolve
    @resolved ||= ErrorType.new(['InferenceError', @position])
  end

  def position
    @position
  end

  def position=(pos:Position)
    @position = pos
  end

  def onUpdate(listener:TypeListener):void
    @listeners.add(listener)
    listener.updated(self, inferredType) if isResolved
  end

  def resolved(type:ResolvedType):void
    if !type.equals(@resolved)
      @resolved = type
      @listeners.each do |l|
        TypeListener(l).updated(self, type)
      end
    end
  end
end

class AssignableTypeFuture < BaseTypeFuture
  def initialize(position:Position)
    super(position)
    @assignments = HashMap.new
    @declarations = HashMap.new
  end

  def declare(type:TypeFuture, position:Position):TypeFuture
    base_type = self
    if @declarations.containsKey(type)
      TypeFuture(@declarations[type])
    elsif @declarations.isEmpty
      type.onUpdate do |t, value|
        base_type.resolved(value)
      end
      self.position = position
      @declarations[type] = self
    else
      @declarations[type] = ErrorType.new(['Type redeclared', position, 'First declared', self.position])
    end
  end

  def assign(value:TypeFuture, position:Position):TypeFuture
    if @assignments.containsKey(type)
      TypeFuture(@assignments[type])
    else
      variable = self
      value.onUpdate {variable.checkAssignments}
      assignment = BaseTypeFuture.new(position)
      onUpdate do |variable, type|
        if value.isResolved && !type.assignableFrom(value.resolve)
          assignment.resolved(variable.incompatibleWith(value.resolve, position))
        else
          assignment.resolved(type)
        end
      end
      @assignments[value] = assignment
    end
  end

  def incompatibleWith(value:ResolvedType, position:Position)
    ErrorType.new(["Cannot assign #{value} to #{inferredType}", position])
  end
end

class MaybeInline < BaseTypeFuture
  def initialize(node:Node, type:TypeFuture, altType:TypeFuture, altNode:Node)
    @inlined = false
    me = self
    altType.onUpdate do |x, value|
      if me.inlined || value.name != ':error'
        unless me.inlined
          me.inlined = true
          node.parent.replaceChild(node, altNode)
        end
        me.resolved(value)
      end
    end
    type.onUpdate do |x, value|
      unless me.inlined
        me.resolved(value)
      end
    end
  end

  def inlined=(inlined:boolean):void
    @inlined = inlined
  end
  def inlined:boolean
    @inlined
  end
end

interface PickerListener do
  def picked(selection:TypeFuture, value:Object):void; end
end

class PickFirst < BaseTypeFuture
  def initialize(items:List, listener:PickerListener)
    @picked = -1
    @listener = listener
    items.size.times do |i|
      next if i % 2 != 0
      addItem(i, TypeFuture(items.get(i)), items.get(i + 1))
    end
  end

  def picked
    @picked
  end

  def pick(index:int, type:TypeFuture, value:Object, resolvedType:ResolvedType)
    if @picked != index
      @picked = index
      @listener.picked(type, value)
    end
    self.resolved(resolvedType)
  end

  private
  def addItem(index:int, type:TypeFuture, value:Object):void
    me = self
    type.onUpdate do |x, resolved|
      if (me.picked == -1 && resolved.name != ':error') ||
          me.picked >= index
        me.pick(index, type, value, resolved)
      end
    end
  end
end
