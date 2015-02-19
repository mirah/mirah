# Copyright (c) 2013 The Mirah project authors. All Rights Reserved.
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

import java.beans.Introspector
import java.beans.IndexedPropertyDescriptor
import java.util.concurrent.locks.ReentrantLock
import java.util.Arrays
import java.util.List
import java.util.Map.Entry

import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.TypeFuture
import org.mirah.util.SimpleDiagnostics
import org.mirah.util.MirahDiagnostic

class ConsoleDiagnostics < SimpleDiagnostics
  def initialize
    super(false)
    @console = System.console
  end
  def log(kind, position, message)
    @console.writer.println(message)
  end
end

interface Command
  def run(args:String[]):void; end
end

class ConsoleDebugger implements DebugListener, Runnable
  macro def registerCommand(hash:Hash)
    e = hash.get(0)
    quote {@commands.put(`e.key`, lambda(Command) {|x| debugger.`e.value`(x)})}
  end
  def initialize
    @controller = DebugController.new(self)
    @controller.step
    @lock = ReentrantLock.new
    @condition = @lock.newCondition
    @stopped = false
    @console = System.console
    @out = ConsoleDiagnostics.new
    @shouldExit = false
    @commands = {}
    debugger = self

    registerCommand c: doContinue
    registerCommand cont: doContinue
    registerCommand s: doStep
    registerCommand step: doStep
    registerCommand 'next' => doNext
    registerCommand n: doNext
    registerCommand help: doHelp
    registerCommand watch: addWatch
    registerCommand watches: listWatches
    registerCommand unwatch: clearWatch
    registerCommand quit: doQuit
    registerCommand b: addBreakpoint
    registerCommand stop: addBreakpoint
    registerCommand del: clearBreakpoint
    registerCommand clear: clearBreakpoint
    registerCommand print: printObject
    registerCommand p: printObject
    registerCommand dump: dumpObject
    registerCommand x: dumpObject
    registerCommand bt: printNodeStack
    registerCommand where: printNodeStack
    registerCommand jwhere: printJavaStack
    registerCommand finish: doFinish
    
  end
  def start
    Thread.new(self).start
  end

  def debugger
    @controller
  end

  def printContext:void
    where = @controller.where
    node_state = if where.result
      "Completed"
    elsif where.watch
      "In"
    else
      "Entering"
    end
    node = where.node
    location = if node.position
      " at #{node.position.source.name}:#{node.position.startLine}"
    else
      ""
    end
    @out.report(MirahDiagnostic.note(
        node.position, "#{node_state} #{node.getClass.getSimpleName}#{location}"))
    if where.result
      printFuture("ret", where.result)
    elsif where.watch
      printWatch(where.watch)
    end
  end

  def printFuture(name:String, future:TypeFuture):void
    @console.printf("  %s = %s%n", name, future)
  end

  def printWatch(watch:WatchState):void
    printFuture("future", watch.future)
    @console.printf("  from = %s%n", watch.currentValue)
    @console.printf("  to = %s%n", watch.newValue)
    import static org.mirah.util.Comparisons.*
    if areSame(watch.currentValue, watch.newValue)
      @console.printf("  (from === to)%n")
    elsif watch.currentValue && watch.currentValue.equals(watch.newValue)
      @console.printf("  (from.equals(to))%n")
    else
      @console.printf("  (from != to)%n")
    end
  end

  def stopped
    @lock.lock
    @stopped = true
    @condition.signal
  ensure
    @lock.unlock
  end

  def processCommand:void
    line = @console.readLine("> ")
    if line.nil?
      @stopped = false
      @shouldExit = true
    else
      split = line.split("\\s+")
      command = split[0]
      unless command.nil? || "".equals(command)
        args = String[].cast(Arrays.copyOfRange(split, 1, split.length))
        handler = Command(@commands[command])
        if handler
          handler.run(args)
        else
          @console.printf("Unsupported command '%s'.%n", command)
        end
      end
    end
  rescue => ex
    ex.printStackTrace
  end

  def run
    @lock.lock
    until @shouldExit
      until @stopped
        @condition.await
      end
      printContext
      while @stopped
        processCommand
      end
    end
  ensure
    @lock.unlock
  end

  def doQuit(args:String[]):void
    @stopped = false
    @shouldExit = true
    System.exit(1)
  end

  def doContinue(args:String[]):void
    @stopped = false
    @controller.continueExecution
  end

  def doStep(args:String[]):void
    if args.length == 1 && "up".equals(args[0])
      doFinish(args)
    else
      @stopped = false
      @controller.step
    end
  end

  def doNext(args:String[]):void
    @stopped = false
    @controller.next
  end

  def doFinish(args:String[]):void
    @stopped = false
    @controller.finishNode
  end

  def doHelp(args:String[]):void
    console = @console
    console.printf("Supported commands:%n")
    @commands.keySet.each {|c| console.printf("\t#{c}")}
    console.printf("%n")
  end

  def listWatches(args:String[]):void
    watches = @controller.watches
    i = 0
    watches.keySet.each do |f:TypeFuture|
      printFuture("#{i}", f)
      i += 1
    end
  end

  def clearWatch(args:String[]):void
    if args.length == 0
      listWatches(args)
      return
    end
    index = Integer.parseInt(args[0])
    it = @controller.watches.keySet.iterator
    (index - 1).times { it.next }
    @controller.clearWatch(BaseTypeFuture(it.next))
  end

  def addWatch(args:String[]):void
    nameIndex = 0
    kind = 'notsame'
    if args.length > 0 
      if @controller.isValidWatchKind(args[0])
        nameIndex = 1
        kind = args[0]
      end
    end
    future = BaseTypeFuture(resolveObject(args, nameIndex))

    if future.nil?
      @console.printf("Nothing to watch%n")
    else
      @controller.watch(BaseTypeFuture(future), kind)
    end
  end

  def listBreakpoints(args:String[]):void
    breakpoints = @controller.breakpoints
    i = 0
    breakpoints.each do |b|
      @console.printf(" %d: %s%n", i, b)
      i += 1
    end
  end

  def clearBreakpoint(args:String[]):void
    if args.length == 0
      listBreakpoints(args)
      return
    end
    index = Integer.parseInt(args[0])
    @controller.breakpoints.each do |b|
      if (index -= 1) < 0
        @controller.clearBreakpoint(Breakpoint(b))
        break
      end
    end
  end

  def addBreakpoint(args:String[]):void
    if args.length == 0
      listBreakpoints(args)
      return
    end
    arg = args[0]
    if arg.equals("at")
      arg = args[1]
    end
    split = arg.split(":", 2)
    bp = Breakpoint.new(split[0], Integer.parseInt(split[1]))
    @controller.addBreakpoint(bp)
  end

  def printObject(args:String[]):void
    what = resolveObject(args, 0)
    @console.printf("\t%s: %s%n", what.getClass.getName, what)
  end

  def dumpObject(args:String[]):void
    what = resolveObject(args, 0)
    if what.kind_of?(BaseTypeFuture)
      dumpFuture(BaseTypeFuture(what))
    else
      printObject(args)
    end
  end

  def dumpFuture(future:BaseTypeFuture):void
    @console.printf("\t%s {%n", future)
    if future.isResolved
      @console.printf("\t\tresolved = %s%n", future.resolve)
    else
      @console.printf("\t\tunresolved%n")
    end
    future.getComponents.entrySet.each do |e:Entry|
      @console.printf("\t\t%s = %s%n", e.getKey, e.getValue)
    end
    @console.printf("\t}%n")
  end

  def resolveObject(args:String[], index:int):Object
    where = @controller.where
    if args.length <= index
      if where.result
        return where.result
      elsif where.watch
        return where.watch.future
      else
        where.node
      end
    else
      components = args[index].split("[.]")
      name = components[0]
      value = if "node".equals(name)
        where.node
      elsif "ret".equals(name)
        where.result
      elsif "future".equals(name)
        where.watch.future
      elsif "from".equals(name)
        where.watch.currentValue
      elsif "to".equals(name)
        where.watch.newValue
      else
        raise IllegalArgumentException.new("Unrecognized name '#{name}'")
      end
      resolveProperties(value, components, 1)
    end
  end

  def resolveProperties(value:Object, components:String[], index:int):Object
    while index < components.length
      name = components[index]
      property_index = -1
      m = /([^\[]+)\[(\d+)\]/.matcher(name)
      if m.matches
        name = m.group(1)
        property_index = Integer.parseInt(m.group(2))
      end
      index += 1
      prop = nil
      if value.kind_of?(BaseTypeFuture)
        btf = BaseTypeFuture(value)
        if "resolved".equals(name) && btf.isResolved
          prop = btf.resolve
        else
          prop = btf.getComponents[name]
        end
      end
      if prop.nil?
        info = Introspector.getBeanInfo(value.getClass)
        info.getPropertyDescriptors.each do |p|
          if name.equals(p.getName)
            if property_index != -1
              method = IndexedPropertyDescriptor(p).getIndexedReadMethod
              prop = method.invoke(value, property_index)
              property_index = -1
            else
              method = p.getReadMethod
              prop = method.invoke(value)
            end
            break
          end
        end
      end
      if prop.nil?
        method = value.getClass.getMethod(name)
        if method
          prop = method.invoke(value)
        end
      end
      if property_index != -1
        if prop.kind_of?(List)
          prop = List(prop).get(property_index)
        elsif prop.getClass.isArray
          prop = Object[].cast(prop)[property_index]
        end
      end
      if prop.nil?
        raise IllegalArgumentException.new("Unrecognized property '#{name}'")
      end
      value = prop
    end
    value
  end

  def printNodeStack(args:String[]):void
    frame = @controller.where
    i = 0
    while frame
      node = frame.node
      position = if node.position
        "#{node.position.source.name}:#{node.position.startLine}"
      else
        ""
      end
      @console.printf("\t%d\t%s %s%n", i, node.getClass.getSimpleName, position)
      i += 1
      frame = frame.parent
    end
  end

  def printJavaStack(args:String[]):void
    @controller.javaStack.each do |frame|
      @console.printf("\t%s%n", frame)
    end
  end
end