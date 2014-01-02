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

package org.mirah.typer

class FuturePrinter
  def initialize
    @out = StringBuilder.new
    @level = 0
    @newline = true
    @cycles = {}
  end

  def printFuture(future:TypeFuture):void
    maybeStartLine
    @level += 1
    if future
      self.write(future.getClass.getSimpleName)
      self.write(" ")
      if @cycles.containsKey(future)
        self.writeLine(@cycles.get(future).toString)
      else
        i = @cycles.size
        @cycles.put(future, Integer.new(i))
        position = if future.kind_of?(BaseTypeFuture)
          BaseTypeFuture(future).position
        else
          nil
        end
        tail = if position
          " #{position.source.name}:#{position.startLine}"
        else
          ""
        end
        self.writeLine("#{i}#{tail}")
        future.dump(self)
      end
    else
      self.writeLine("null")
    end
    @level -= 1
  end

  def write(text:String):void
    maybeStartLine
    @out.append(text)
  end

  def writeLine(text:String):void
    maybeStartLine
    @out.append(text)
    @out.append("\n")
    @newline = true
  end

  def maybeStartLine:void
    if @newline
      i = 0
      while i < @level - 1
        @out.append("|   ")
        i += 1
      end
      if i < @level
        @out.append("|-- ")
      end
      @newline = false
    end
  end

  def toString
    @out.toString
  end
end