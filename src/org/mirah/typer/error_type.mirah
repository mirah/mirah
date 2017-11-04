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

class ErrorMessage
  attr_reader message: String, position: Position
  #attr_writer position: Position

  def initialize message: String, position: Position=nil
    @message = message
    @position = position
  end

  def hasPosition
    !@position.nil?
  end

  def setPosition(position: Position): void
    @position = position
  end

  def equals other
    other.kind_of?(ErrorMessage) &&
    Objects.equals(@message, other.as!(ErrorMessage).message) &&
    Objects.equals(@position, other.as!(ErrorMessage).position)
  end

  def hashCode
    Objects.hash(@message, @position)
  end
end


# An error.
class ErrorType < SpecialType

  def self.empty
    new(Collections.emptyList)
  end

  # message is a list of ErrorMessages. Typically there's only one
  # item in list, but multiple is possible (for example an error that refers
  # to both the beginning and end of a block)
  def initialize(messages: List)
    super(":error")
    @messages = checkMessage(messages)
  end

  def messages:List
    @messages
  end

  def matchesAnything; true; end

  def assignableFrom(other)
    false # error types can't be assigned from any other type
  end

  def toString:String
    "<Error: #{messages}>"
  end

  def getMessageString: String
    messages.toString
  end

  def equals(other:Object)
    other.kind_of?(ErrorType) && messages.equals(other.as!(ErrorType).messages)
  end

  def hashCode
    messages.hashCode
  end

  # private

  def checkMessage(messages: List)
    messages.each do |error: ErrorMessage|
      # type check
      text = error.message
      position = error.position

    end
    messages
  end

  def isFullyResolved:boolean
    false
  end
end
