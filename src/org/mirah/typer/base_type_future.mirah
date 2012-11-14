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
import java.util.logging.Logger
import java.util.logging.Level
import mirah.lang.ast.*

# Base class for most TypeFutures.
# Implements listeners and supports generating error messages.
# Thread hostile
class BaseTypeFuture; implements TypeFuture
  def initialize(position:Position)
    @position = position
    @listeners = ArrayList.new
    @new_listeners = ArrayList(nil)
  end
  def initialize
    @listeners = ArrayList.new
  end

  def self.initialize:void
    @@log = Logger.getLogger(BaseTypeFuture.class.getName)
  end

  def isResolved
    @resolved != nil
  end

  def inferredType
    @resolved
  end

  def resolve
    unless @resolved
      @@log.finest("#{self}: error: #{error_message}")
      @resolved = ErrorType.new([[error_message, @position]])
      notifyListeners
    end
    @resolved
  end

  # The error message used if this future doesn't resolve.
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

  def onUpdate(listener:TypeListener):TypeListener
    if @notifying
      @new_listeners ||= ArrayList.new(@listeners)
      @new_listeners.add(listener)
    else
      @listeners.add(listener)
    end
    listener.updated(self, inferredType) if isResolved
    listener
  end

  def removeListener(listener:TypeListener):void
    if @notifying
      @new_listeners ||= ArrayList.new(@listeners)
      @new_listeners.remove(listener)
    else
      @listeners.remove(listener)
    end
  end

  # Resolves this future to the specified type.
  # Notifies the listeners if the resolved type has changed.
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
      notifyListeners
    end
  end

  def notifyListeners:void
    if @notifying
      @notify_again = true
      return
    end
    @notifying = true
    begin
      @notify_again = false
      type = @resolved
      @listeners.each do |l|
        break if @notify_again
        TypeListener(l).updated(self, type)
      end
    end while @notify_again
    if @new_listeners
      @listeners = @new_listeners
      @new_listeners = nil
    end
    @notifying = false
  end
end
