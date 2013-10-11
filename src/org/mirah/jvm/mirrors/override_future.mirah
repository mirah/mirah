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

package org.mirah.jvm.mirrors

import java.util.ArrayList
import java.util.LinkedHashMap
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.TypeFuture
import org.mirah.typer.ResolvedType
import org.mirah.typer.InlineCode

# Type future for argument/return inferred from a supertype.
# We can only infer if all supertype methods have the same argument type.
class OverrideFuture < BaseTypeFuture
  def initialize
    @types = ArrayList.new
  end

  def error=(error:ResolvedType):void
    @error = error
  end

  def addType(type:TypeFuture):void
    @types.add(type)
    me = self
    type.onUpdate do |_, resolved|
      me.checkTypes
    end
  end

  def error_message:String
    "Incompatible types #{@types.map {|x:TypeFuture| x.resolve}}"
  end

  def checkTypes:void
    resolved = nil
    @types.each do |f:TypeFuture|
      if f.isResolved
        t = f.resolve
        unless t.isError || t.kind_of?(InlineCode)
          type = MirrorType(t)
          if resolved.nil?
            resolved = type
          else
            unless resolved.isSameType(type)
              self.resolved(@error)
              return
            end
          end
        end
      end
    end
    self.resolved(resolved)
  end

  def dump(out)
    out.writeLine("error: #{@error}") if @error
    @types.each do |t:TypeFuture|
      out.printFuture(t)
    end
  end

  def getComponents
    map = LinkedHashMap.new
    map[:types] = ArrayList.new(@types)
    map[:error] = @error if @error
    map
  end
end