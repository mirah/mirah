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

package org.mirah.jvm.mirrors.debug

import java.io.File
import java.util.ArrayList
import java.util.Collections
import java.util.LinkedHashMap
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import java.util.concurrent.Semaphore
import java.util.concurrent.locks.ReentrantLock
import java.util.regex.Pattern

import mirah.lang.ast.Node
import mirah.lang.ast.Position
import org.mirah.typer.TypeFuture
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.ResolutionWatcher
import org.mirah.typer.ResolvedType
import org.mirah.util.Context

interface DebugListener
  def stopped:void; end
end

class Breakpoint
  def initialize(filename:String, line:int)
    @filename = filename
    @pattern = Pattern.compile(
        "(?:^|#{File.separatorChar})#{Pattern.quote(filename)}$")
    @line = line
  end

  def matches(position:Position):boolean
    return false if position.nil?
    return false unless position.startLine == @line
    name = position.source.name
    @pattern.matcher(name).find
  end

  def toString
    "#{@filename}:#{@line}"
  end
end

interface StepPredicate
  def stopBefore(stack:StackEntry):boolean; end
  def stopAfter(stack:StackEntry):boolean; end
end

class SingleStep implements StepPredicate
  def stopBefore(stack)
    true
  end
  def stopAfter(stack)
    true
  end
end

class Next implements StepPredicate
  def initialize(node:Node)
    @node = node
  end
  def stopBefore(stack)
    false
  end
  def stopAfter(stack)
    if stack.node == @node
      return true
    end
    if stack.parent
      stack = stack.parent
      if stack.node == @node
        return true
      end
    end
    false
  end
end

class Finish implements StepPredicate
  def initialize(node:Node)
    @node = node
  end
  def stopBefore(stack)
    false
  end
  def stopAfter(stack)
    if stack.node == @node
      return true
    end
    while stack.parent
      stack = stack.parent
      if stack.node == @node
        return false
      end
    end
    true
  end
end

interface WatchPredicate
  def test(a:ResolvedType, b:ResolvedType):boolean; end
end

class WatchState
  def initialize(
      future:BaseTypeFuture, currentValue:ResolvedType, newValue:ResolvedType)
    @future = future
    @currentValue = currentValue
    @newValue = newValue
  end

  attr_reader future:BaseTypeFuture, currentValue:ResolvedType
  attr_reader newValue:ResolvedType
end

class StackEntry
  def initialize(context:Context, node:Node, expression:boolean, parent:StackEntry)
    @context = context
    @node = node
    @expression = expression
    @parent = parent
  end
  attr_reader node:Node, expression:boolean, context:Context
  attr_accessor result:TypeFuture, watch:WatchState
  attr_accessor parent:StackEntry
end

class DebugController implements DebuggerInterface, ResolutionWatcher
  def initialize(listener:DebugListener,
                 executor:Executor=Executors.newSingleThreadExecutor)
    @lock = ReentrantLock.new
    @condition = @lock.newCondition
    @stopped = false
    @breakpoints = ArrayList.new
    @watches = LinkedHashMap.new
    @step = StepPredicate(nil)
    @listener = listener
    @executor = executor
    @predicates = {
      all: lambda(WatchPredicate) {|a, b| true},
      same: lambda(WatchPredicate) {|a, b| a == b},
      notsame: lambda(WatchPredicate) {|a, b| a != b},
      eq: lambda(WatchPredicate) {|a, b| a && a.equals(b)},
      ne: lambda(WatchPredicate) {|a, b| a != b && (a.nil? || !a.equals(b))}
    }
    @asts = []
  end

  def where:StackEntry
    @lock.lock
    @stack
  ensure
    @lock.unlock
  end

  def javaStack
    @lock.lock
    @thread.getStackTrace
  ensure
    @lock.unlock
  end

  def continueExecution:void
    @lock.lock
    @step = nil
    unblock
  ensure
    @lock.unlock
  end

  def step:void
    @lock.lock
    @step = SingleStep.new
    unblock
  ensure
    @lock.unlock
  end

  def next:void
    @lock.lock
    @step = if @stack.result.nil?
      # We're stopped before a node, wait till it finishes
      Next.new(@stack.node)
    else
      if @stack.parent
        Next.new(@stack.parent.node)
      else
        nil
      end
    end
    unblock
  ensure
    @lock.unlock
  end

  def finishNode:void
    @lock.lock
    @step = if @stack.result.nil?
      # We're stopped before a node, wait till it finishes
      Finish.new(@stack.node)
    else
      if @stack.parent
        Finish.new(@stack.parent.node)
      else
        nil
      end
    end
    unblock
  ensure
    @lock.unlock
  end

  def watches
    @lock.lock
    Collections.unmodifiableMap(@watches)
  ensure
    @lock.unlock
  end

  def isValidWatchKind(kind:String):boolean
    @predicates.containsKey(kind)
  end

  def watch(future:BaseTypeFuture, kind:String):boolean
    predicate = @predicates[kind]
    unless predicate
      return false
    end
    @lock.lock
    begin
      @watches[future] = predicate
    ensure
      @lock.unlock
    end
    future.watchResolves(self)
    true
  end

  def clearWatch(future:BaseTypeFuture):void
    @lock.lock
    @watches.remove(future)
  ensure
    @lock.unlock
  end

  def breakpoints
    @lock.lock
    Collections.unmodifiableList(@breakpoints)
  ensure
    @lock.unlock
  end

  def clearBreakpoint(breakpoint:Breakpoint)
    @lock.lock
    @breakpoints.remove(breakpoint)
  ensure
    @lock.unlock
  end

  def addBreakpoint(breakpoint:Breakpoint)
    @lock.lock
    @breakpoints.add(breakpoint)
  ensure
    @lock.unlock
  end

  def parsedNode(node)
    @asts.add(node)
  end

  def getAllParsedNodes
    @asts
  end

  def inferenceError(context, node, error)
    @lock.lock
    begin
      @stack = StackEntry.new(context, node, true, StackEntry(@stack))
      @stack.result = error
    ensure
      @lock.unlock
    end

    self.block

    @lock.lock
    begin
      @stack = @stack.parent
    ensure
      @lock.unlock
    end
  end

  def enterNode(context, node, expression)
    should_stop = false
    @lock.lock
    begin
      @stack = StackEntry.new(context, node, expression, StackEntry(@stack))
      position = node.position
      if @step && @step.stopBefore(@stack)
        should_stop = true
      elsif position
        @breakpoints.each do |b:Breakpoint|
          if b.matches(position)
            should_stop = true
            break
          end
        end
      end
    ensure
      @lock.unlock
    end

    self.block if should_stop
  end

  def exitNode(context, node, result)
    @lock.lock
    should_stop = false
    begin
      @stack.result = result
      if @step && @step.stopAfter(@stack)
        should_stop = true
      end
    ensure
      @lock.unlock
    end
    self.block if should_stop
    @lock.lock
    begin
      @stack = @stack.parent
    ensure
      @lock.unlock
    end
  end

  def resolved(future, currentValue, newValue)
    @lock.lock
    begin
      predicate = WatchPredicate(@watches[future])
      unless predicate && predicate.test(currentValue, newValue)
        return
      end
      entry = @stack
      entry.watch = WatchState.new(future, currentValue, newValue)
    ensure
      @lock.unlock
    end
    self.block
    @lock.lock
    begin
      @stack.watch = nil
    ensure
      @lock.unlock
    end
  end

  # Should be called only from Typer thread
  def block
    @lock.lock
    @stopped = true
    @thread ||= Thread.currentThread
    listener = @listener
    @executor.execute { listener.stopped }
    while @stopped
      @condition.await
    end
  ensure
    @lock.unlock
  end

  # Should be called only from controller thread
  def unblock
    @lock.lock
    @stopped = false
    @condition.signal
  ensure
    @lock.unlock
  end
end