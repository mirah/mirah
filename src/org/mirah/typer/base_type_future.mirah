# Copyright (c) 2012-2014 The Mirah project authors. All Rights Reserved.
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
import java.util.concurrent.locks.ReentrantLock
import org.mirah.util.Logger
import java.util.logging.Level
import mirah.lang.ast.*

# Should there be an UpdateWatcher?
interface ResolutionWatcher
  def resolved(
      future: BaseTypeFuture, current: ResolvedType, resolved: ResolvedType):void
  end
end

# Base class for most TypeFutures.
# Implements listeners and supports generating error messages.
# Thread hostile
class BaseTypeFuture; implements TypeFuture
  def initialize(position: Position)
    @position = position
    @listeners = ArrayList.new
    @new_listeners = ArrayList(nil)
    @notify_depth = 0
    @lock = ReentrantLock.new
  end
  def initialize
    @listeners = ArrayList.new
    @lock = ReentrantLock.new
  end

  def self.initialize: void
    @@log = Logger.getLogger(BaseTypeFuture.class.getName)
  end

  def watchResolves(watcher: ResolutionWatcher): void
    @watcher = watcher
  end

  def isResolved
    @resolved != nil
  end

  def inferredType
    @resolved
  end

  def peekInferredType
    @resolved
  end

  def resolve
    unless @resolved
      @@log.finest("#{self}: error: #{error_message}")
      @resolved = ErrorType.new([ErrorMessage.new(error_message, @position)])
      notifyListeners
    end
    @resolved
  end

  # The error message used if this future doesn't resolve.
  def error_message
    @error_message || "InferenceError: no message #{position} #{getClass}"
  end

  def error_message=(message: String)
    @error_message = message
  end

  def position
    @position
  end

  def position=(pos: Position)
    @position = pos
  end

  def onUpdate(listener: TypeListener): TypeListener
    begin
      @lock.lock
      if @notify_depth > 0
        @new_listeners ||= ArrayList.new(@listeners)
        @new_listeners.add(listener)
      else
        @listeners.add(listener)
      end
    ensure
      @lock.unlock
    end
    listener.updated(self, inferredType) if isResolved
    listener
  end

  def removeListener(listener: TypeListener): void
    @lock.lock
    if @notify_depth > 0
      @new_listeners ||= ArrayList.new(@listeners)
      @new_listeners.remove(listener)
    else
      @listeners.remove(listener)
    end
  ensure
    @lock.unlock
  end

  # Resolves this future to the specified type.
  # Notifies the listeners if the resolved type has changed.
  def resolved(type: ResolvedType): void
    @@log.fine "resolving as #{type} from #{resolved_str}"
    @lock.lock
    if @watcher
      @watcher.resolved(self, @resolved, type)
    end
    if type.nil?
      if type == @resolved
        return
      else
        type = ErrorType.new(Collections.emptyList)
      end
    end
    if !type.equals(@resolved)
      @resolved = type
      notifyListeners
    end
  ensure
    @lock.unlock
  end

  def forgetType
    @@log.finest "forgetting previous type #{resolved_str}"
    @resolved = nil
  end

  def notifyListeners: void
    @lock.lock
    @notify_depth += 1
    if @notify_depth > 100
      raise IllegalStateException, "Type inference loop"
    elsif @notify_depth == 90
      @@log.severe("Type cycle detected, enabling debug logging.")
      Logger.getLogger('org.mirah').setLevel(Level.ALL)
    end

    @listeners.each do |l: TypeListener|
      l.updated(self, @resolved)
    end
  ensure
    if 0 == (@notify_depth -= 1)
      if @new_listeners
        @listeners = @new_listeners
        @new_listeners = nil
      end
    end
    @lock.unlock
  end

  def toString
    "<#{getClass.getSimpleName}: resolved=#{resolved_str}, listenerCt=#{@listeners.size}>"
  end

  def dump(out: FuturePrinter): void
    out.writeLine(String.valueOf(@resolved))
  end

  def getComponents
    Collections.emptyMap
  end

  def resolved_str: String
    type_str @resolved
  end

  def type_str(type: ResolvedType): String
    return "undefined" unless type
    type.toString
  end

end
