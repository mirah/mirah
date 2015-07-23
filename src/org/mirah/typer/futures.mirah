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

interface TypeListener do
  def updated(src:TypeFuture, value:ResolvedType):void; end
end

interface ResolvedType do
  def widen(other:ResolvedType):ResolvedType; end
  def assignableFrom(other:ResolvedType):boolean; end
  def name:String; end
  def isMeta:boolean; end
  def isBlock:boolean; end
  def isInterface:boolean; end
  def isError:boolean; end
  def matchesAnything:boolean; end
  def isFullyResolved:boolean; end
end

interface GenericType do
  def type_parameter_map:HashMap; end
end

interface TypeFuture do
  # Whether the ResolvedType is available.
  def isResolved:boolean; end

#  # Whether the ResolvedType is available and will not change anymore, even regarding its superclasses and superinterfaces.
#  def isFullyResolved:boolean; end
    
  # Returns the resolved type for this future, or an ErrorType if not yet resolved.
  def resolve:ResolvedType; end

  # Allows to peek into the current state of what could be the resolved type, without triggering resolution.
  def peekInferredType:ResolvedType; end

  # Add a listener for this future.
  # listener will be called whenever this future resolves to a different type.
  # If the future is already resolved listener will be immediately called.
  def onUpdate(listener:TypeListener):TypeListener; end

  def removeListener(listener:TypeListener):void; end

  def dump(out:FuturePrinter):void; end

  # Programmatic access to same info as dump for debugging.
  # name -> (TypeFuture or List<TypeFuture>)
  def getComponents:Map; end
end
