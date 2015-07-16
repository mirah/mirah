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
import mirah.lang.ast.*

# An error.
class ErrorType < SpecialType

  # message is a list of [message, position] pairs. Typically there's only one
  # item in list, but multiple is possible (for example an error that refers
  # to both the beginning and end of a block)
  def initialize(message:List)
    super(":error")
    @message = checkMessage(message)
  end

  def message:List
    @message
  end

  def matchesAnything; true; end

  def assignableFrom(other)
    false # error types can't be assigned from any other type
  end

  def toString:String
    "<Error: #{message}>"
  end

  def equals(other:Object)
    other.kind_of?(ErrorType) && message.equals(ErrorType(other).message)
  end

  def hashCode
    message.hashCode
  end

  # private

  def checkMessage(message:List)
    new_message = ArrayList.new(message.size)
    message.each do |_pair|
      pair = List(_pair)
      text = String(pair.get(0))
      position = pair.size > 1 ? Position(pair.get(1)) : nil
      new_pair = ArrayList.new(2)
      new_pair.add(text)
      new_pair.add(position)
      new_message.add(new_pair)
    end
    new_message
  end

  def isFullyResolved:boolean
    false
  end
end
