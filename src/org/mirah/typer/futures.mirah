package org.mirah.typer
import java.util.*
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
  def resolve:ResolvedType; end
  def onUpdate(listener:TypeListener):void; end
  def removeListener(listener:TypeListener):void; end
end

class SimpleFuture; implements TypeFuture
  def initialize(type:ResolvedType)
    @type = type
  end
  def isResolved() true end
  def resolve() @type end
  def onUpdate(listener) listener.updated(self, @type) end
    def removeListener(listener); end
end

class BaseTypeFuture; implements TypeFuture
  def initialize(position:Position)
    @position = position
    @listeners = ArrayList.new
  end
  def initialize
    @listeners = ArrayList.new
  end

  def isResolved
    @resolved != nil
  end

  def inferredType
    @resolved
  end

  def resolve
    @resolved ||= ErrorType.new([[error_message, @position]])
  end

  def error_message
    @error_message || 'InferenceError'
  end

  def error_message=(message:String)
    @error_message = message
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

  def removeListener(listener:TypeListener):void
    @listeners.remove(listener)
  end

  def resolved(type:ResolvedType):void
    if type.nil?
      if type == @resolved
        return
      else
        type = ErrorType.new(Collections.emptyList)
      end
    end
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
      TypeFuture(self)
    else
      TypeFuture(@declarations[type] = ErrorType.new([['Type redeclared', position], ['First declared', self.position]]))
    end
  end

  def assign(value:TypeFuture, position:Position):TypeFuture
    if @assignments.containsKey(value)
      TypeFuture(@assignments[value])
    else
      variable = self
      assignment = BaseTypeFuture.new(position)
      @assignments[value] = assignment
      value.onUpdate do |x, resolved|
        variable.checkAssignments
        if resolved.isError
          assignment.resolved(resolved)
        elsif variable.isResolved
          if variable.resolve.assignableFrom(resolved)
            assignment.resolved(variable.resolve)
          else
            assignment.resolved(variable.incompatibleWith(value.resolve, position))
          end
        end
      end
      TypeFuture(assignment)
    end
  end

  def incompatibleWith(value:ResolvedType, position:Position)
    ErrorType.new([["Cannot assign #{value} to #{inferredType}", position]])
  end

  def hasDeclaration:boolean
    !@declarations.isEmpty
  end

  def assignedValues(includeParent:boolean, includeChildren:boolean):Collection
    Collection(@assignments.keySet)
  end

  def checkAssignments:void
    if hasDeclaration
      return
    end
    type = ResolvedType(nil)
    error = ResolvedType(nil)
    assignedValues(true, true).each do |_value|
      value = TypeFuture(_value)
      if value.isResolved
        resolved = value.resolve
        if resolved.isError
          error ||= resolved
        else
          if type
            type = type.widen(value.resolve)
          else
            type = resolved
          end
        end
      end
    end
    resolved(type || error)
  end
end

# An AssignableTypeFuture that defaults to object when not otherwise constrained, instead of throwing an error.
class GenericTypeFuture < AssignableTypeFuture
  def initialize(position:Position, object:ResolvedType)
    super(position)
    @object = object
  end

  def resolve
    unless isResolved
      resolved(@object)
    end
    super
  end
end

class MaybeInline < BaseTypeFuture
  def initialize(n:Node, type:TypeFuture, altNode:Node, altType:TypeFuture)
    super(n.position)
    node = n
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
      @listener.picked(type, value) if @listener
    end
    self.resolved(resolvedType)
  end

  private
  def addItem(index:int, type:TypeFuture, value:Object):void
    me = self
    i = index
    type.onUpdate do |x, resolved|
      if (me.picked == -1 && resolved.name != ':error') ||
          me.picked >= i
        me.pick(i, type, value, resolved)
      end
    end
  end
end

class CallFuture < BaseTypeFuture
  def initialize(types:TypeSystem, target:TypeFuture, paramTypes:List, call:CallSite)
    initialize(types, target, call.name.identifier, paramTypes, call.parameters, call.position)
  end
  
  def initialize(types:TypeSystem, target:TypeFuture, name:String, paramTypes:List, call:CallSite)
    initialize(types, target, name, paramTypes, call.parameters, call.position)
  end
  
  def initialize(types:TypeSystem, target:TypeFuture, name:String, paramTypes:List, params:NodeList, position:Position)
    super(position)
    @types = types
    @target = target
    @name = name
    @paramTypes = paramTypes
    @params = params
    @resolved_target = ResolvedType(nil)
    @resolved_args = ArrayList.new(paramTypes.size)
    paramTypes.size.times do |i|
      @resolved_args.add(
        if @paramTypes.get(i).kind_of?(BlockFuture)
          types.getBlockType
        else
          nil
        end
      )
    end
    setupListeners
  end

  def parameterNodes:NodeList
    @params
  end

  def resolved_target=(type:ResolvedType):void
    @resolved_target = type
  end
  
  def resolved_target
    @resolved_target
  end
  
  def name
    @name
  end
  
  def resolved_parameters
    @resolved_args
  end

  def setupListeners
    call = self
    @target.onUpdate do |t, type|
      call.resolved_target = type
      call.maybeUpdate
    end
    @paramTypes.each do |_arg|
      next if _arg.kind_of?(BlockFuture)
      arg = TypeFuture(_arg)
      arg.onUpdate do |a, type|
        call.resolveArg(a, type)
      end
    end
  end

  def resolveArg(arg:TypeFuture, type:ResolvedType)
    if type.isError
      resolved(type)
    else
      i = @paramTypes.indexOf(arg)
      @resolved_args.set(i, type)
      maybeUpdate
    end
  end

  def resolveBlocks(type:MethodType, error:ResolvedType)
    @paramTypes.size.times do |i|
      param = @paramTypes.get(i)
      if param.kind_of?(BlockFuture)
        block_type = error || ResolvedType(type.parameterTypes.get(i))
        BlockFuture(param).resolved(block_type)
      end
    end
  end

  def maybeUpdate:void
    if @resolved_target
      if @resolved_target.isError
        @method = TypeFuture(nil)
        resolved(@resolved_target)
        resolveBlocks(nil, @resolved_target)
      elsif @resolved_args.all?
        call = self
        new_method = @types.getMethodType(self)
        if new_method != @method
          #@method.removeListener(self) if @method
          @method = new_method
          @method.onUpdate do |m, type|
            if m == call.currentMethodType
              if type.kind_of?(MethodType)
                mtype = MethodType(type)
                call.resolveBlocks(mtype, nil)
                call.resolved(mtype.returnType)
              else
                unless type.isError
                  raise IllegalArgumentException, "Expected MethodType, got #{type}"
                end
                # TODO(ribrdb) should resolve blocks, return type
                call.resolveBlocks(nil, type)
                call.resolved(type)
              end
            end
          end
        end
      end
    end
  end

  def currentMethodType
    @method
  end
end

class LocalFuture < AssignableTypeFuture
  def initialize(name:String, position:Position)
    super(position)
    self.error_message = "Undefined variable #{name}"
    @children = ArrayList.new
  end

  def checkAssignments
    super
    @parent.checkAssignments if @parent
  end

  def parent=(parent:LocalFuture)
    @parent = parent
    parent.addChild(self)
    checkAssignments
  end

  def addChild(child:LocalFuture)
    @children.add(child)
  end

  def hasDeclaration
    (@parent && @parent.hasDeclaration) || super
  end

  def assignedValues(includeParent, includeChildren)
    if includeParent || includeChildren
      assignments = HashSet.new(super)
      if @parent && includeParent
        assignments.addAll(@parent.assignedValues(true, false))
      end
      if assignments.size > 0 && includeChildren
        @children.each do |child|
          assignments.addAll(LocalFuture(child).assignedValues(false, true))
        end
      end
      Collection(assignments)
    else
      super
    end
  end
end

class BlockFuture < BaseTypeFuture
  def initialize(block:Block, listener:TypeListener)
    super(block.position)
    @block = block
    onUpdate(listener)
  end

  def block
    @block
  end
end

class MethodFuture < BaseTypeFuture
  def initialize(name:String, parameters:List, returnType:AssignableTypeFuture, vararg:boolean, position:Position)
    super(position)
    @methodName = name
    @returnType = returnType
    @vararg = vararg
    mf = self
    raise IllegalArgumentException if parameters.any? {|p| ResolvedType(p).isBlock}
    @returnType.onUpdate do |f, type|
      if type.isError
        mf.resolved(type)
      else
        mf.resolved(MethodType.new(name, parameters, type, mf.isVararg))
      end
    end
  end

  def methodName
    @methodName
  end
  
  def isVararg
    @vararg
  end
  
  def returnType
    @returnType
  end
end
