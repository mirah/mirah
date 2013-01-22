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

interface PickerListener do
  def picked(selection:TypeFuture, value:Object):void; end
end

# Represents an ordered choice between a number of TypeFutures.
class PickFirst < BaseTypeFuture
  def self.initialize:void
    @@log = Logger.getLogger(PickFirst.class.getName)
  end

  # Items must be a list with an even number of elements:
  # [future1, arg1, ..., futureX, argX]
  # futureX and argX are passed to the listener when futureX is chosen.
  # If multiple futures resolve the one that occurs first in items is chosen.
  def initialize(items:List, listener:PickerListener)
    initialize(items, TypeFuture(items.get(0)), listener)
  end

  def initialize(items:List, default:TypeFuture, listener:PickerListener)
    @picked = -1
    @listener = listener
    @default = default
    items.size.times do |i|
      next if i % 2 != 0
      addItem(i, TypeFuture(items.get(i)), items.get(i + 1))
    end
  end
  
  def resolve
    unless isResolved
      # We haven't resolved, so the default must be an error.
      resolved(@default.resolve) 
    end
    super
  end

  def picked
    @picked
  end

  def pick(index:int, type:TypeFuture, value:Object, resolvedType:ResolvedType)
    @@log.finest("#{System.identityHashCode(self)} picked #{index} #{value} #{resolvedType.name}")
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
      if (me.picked == -1 && !resolved.isError) ||
          me.picked >= i
        me.pick(i, type, value, resolved)
      end
    end
  end
end
