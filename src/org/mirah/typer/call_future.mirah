# Copyright (c) 2012 The Mirah project authors. All Rights Reserved.
# All contributing project authors may be found in the NOTICE file.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package org.mirah.typer

import java.util.*
import org.mirah.util.Logger
import java.util.logging.Level
import mirah.lang.ast.*

# Future for a method call.
# Handles interaction with the TypeSystem as the target and parameters of a
# method call resolve.
class CallFuture < BaseTypeFuture
  def self.initialize:void
    @@log = Logger.getLogger(CallFuture.class.getName)
  end

  def self.log
    @@log
  end

  def initialize(types:TypeSystem, scope:Scope, target:TypeFuture, explicitTarget:boolean, paramTypes:List, call:CallSite)
    initialize(types, scope, target, explicitTarget, call.name.identifier, paramTypes, CallFuture.getNodes(call), call.position)
  end

  def initialize(types:TypeSystem, scope:Scope, target:TypeFuture, explicitTarget:boolean, name:String, paramTypes:List, call:CallSite)
    initialize(types, scope, target, explicitTarget, name, paramTypes, CallFuture.getNodes(call), call.position)
  end

  def initialize(types:TypeSystem, scope:Scope, target:TypeFuture, explicitTarget:boolean, name:String, paramTypes:List, paramNodes:List, position:Position)
    super(position)
    @scope = scope
    @types = types
    @target = target
    @explicitTarget = explicitTarget
    @name = name
    @paramTypes = paramTypes
    @params = paramNodes
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
    # if target is nil, this is probably an orphaned node.
    # So just let it be an error.
    if target
      setupListeners
    end
  end

  def dump(out)
    out.write("resolved: ")
    super
    out.write("target: ")
    out.printFuture(@target)
    out.writeLine("name: #{@name}")
    @paramTypes.each do |p|
      out.printFuture(TypeFuture(p))
    end
  end

  def getComponents
    map = LinkedHashMap.new
    map[:target] = @target
    map[:name] = @name
    map[:params] = ArrayList.new(@paramTypes)
    map
  end

  def self.getNodes(call:CallSite):List
    l = LinkedList.new
    call.parameters.each {|p| l.add(p)} if call.parameters
    l.add(call.block) if call.block
    l
  end

  def scope
    @scope
  end

  def parameterNodes:List
    @params
  end

  def explicitTarget:boolean
    @explicitTarget
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

  def futures
    @paramTypes
  end

  def dt(type:TypeFuture)
    "#{type} (#{(type &&type.isResolved) ? type.resolve.toString : 'unresolved'})"
  end

  def setupListeners
    call = self
    @@log.finer("Adding target listener for #{dt(@target)}")
    @target.onUpdate do |t, type|
      call.resolved_target = type
      call.maybeUpdate
    end
    @paramTypes.size.times do |i|
      arg = TypeFuture(@paramTypes.get(i))
      next if arg.kind_of?(BlockFuture)
      addParamListener(i, arg)
    end
  end

  def resolve
    unless isResolved
      @target.resolve
      @paramTypes.size.times do |i|
        arg = TypeFuture(@paramTypes.get(i))
        next if arg.kind_of?(BlockFuture)
        arg.resolve
      end
      @method.resolve if @method
    end
    super
  end

  def addParamListener(i:int, arg:TypeFuture):void
    index = i
    @@log.finer("Adding param listener #{i} for #{dt(arg)}")
    call = self
    arg.onUpdate do |a, type|
      call.resolveArg(index, a, type)
    end
  end

  def resolveArg(i:int, arg:TypeFuture, type:ResolvedType):void
    if type.kind_of?(InlineCode)
      @@log.finest("Skipped resolving InlineCode arg")
      return
    end
    @resolved_args.set(i, type)
    @@log.finer("resolved arg #{i} #{dt(arg)}")
    maybeUpdate
  end

  def resolveBlocks(type:MethodType, error:ResolvedType):void
    if type && type.returnType.kind_of?(InlineCode)
      return
    end
    @paramTypes.size.times do |i|
      param = @paramTypes.get(i)
      if param.kind_of?(BlockFuture)
        block_type = error || ResolvedType(type.parameterTypes.get(i))
        BlockFuture(param).resolved(block_type)
      end
    end
  end

  def getArgError:ResolvedType
    @resolved_args.each do |arg:ResolvedType|
      if arg && arg.isError
        return arg
      end
    end
    nil
  end

  def maybeUpdate:void
    @@log.log(Level.FINER, "maybeUpdate(name=#{name}, target=#{@resolved_target}, args=#{@resolved_args})")
    if @resolved_target
      if @resolved_target.isError
        @method = TypeFuture(nil)
        resolved(@resolved_target)
        resolveBlocks(nil, @resolved_target)
      else
        call = self
        new_method = @types.getMethodType(self)
        if new_method != @method
          #@method.removeListener(self) if @method
          @method = new_method
          resolved_target = @resolved_target
          void_type = @types.getVoidType().resolve
          scope = @scope
          _log = log
          @method.onUpdate do |m, type|
            if m == call.currentMethodType
              if type.kind_of?(MethodType)
                mtype = MethodType(type)
                call.resolveBlocks(mtype, nil)
                is_void = void_type.equals(mtype.returnType)

                if scope.selfType.resolve == resolved_target
                  scope.methodUsed(call.name)
                  _log.fine "got here for #{call} with scope #{scope}"
                end

                if is_void
                  call.resolved(resolved_target)
                else
                  call.resolved(mtype.returnType)
                end
              else
                unless type.isError
                  raise IllegalArgumentException, "Expected MethodType, got #{type}"
                end
                # TODO(ndh) maybe undo the scope.methodUsed here.
                #      I'm not 100% sure of the circumstances where that'd be necessary,
                #      so I should come up with a test case.
                # TODO(ribrdb) should resolve blocks, return type
                error = call.getArgError || type
                call.resolveBlocks(nil, error)
                call.resolved(error)
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

  def toString
    "<#{getClass.getSimpleName}: name=#{@name} target=#{@target} resolved: #{@resolved_target} params=#{@params} paramTypes=#{@paramTypes} resolved: #{@resolved_args}>"
  end
end
