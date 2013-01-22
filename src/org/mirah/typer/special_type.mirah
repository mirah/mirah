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

# A ResolvedType that is also a Future to itself.
class SpecialType; implements ResolvedType, TypeFuture
  def initialize(name:String)
    @name = name
  end
  def isInterface
    false
  end
  def isResolved
    true
  end
  def resolve
    ResolvedType(self)
  end
  def name
    @name
  end
  def widen(other)
    self
  end
  def assignableFrom(other)
    true
  end
  def onUpdate(l)
    l.updated(self, self)
  end
  def equals(other:Object)
    other.kind_of?(ResolvedType) && ResolvedType(other).name == @name
  end
  def hashCode
    name.hashCode
  end
  def toString
    "<#{getClass.getSimpleName}: #{name}>"
  end
  def isMeta; false; end
  def isError; ":error".equals(name); end
  def isBlock; ":block".equals(name); end
  def matchesAnything; false; end
end
