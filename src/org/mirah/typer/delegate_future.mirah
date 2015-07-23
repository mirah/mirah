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

# Delegates to another type future.
class DelegateFuture < BaseTypeFuture
  def isResolved()
    @type && @type.isResolved
  end

  def resolve()
    if @type
      @type.resolve
    else
      super
    end
  end

  # The current delegate
  def type
    @type
  end

  # Set the delegate TypeFuture.
  def type=(type:TypeFuture):void
    if @type
      import static org.mirah.util.Comparisons.*
      if areSame(@type, type)
        return
      else
        @type.removeListener(@listener)
      end
    end
    @type = type
    delegate = self
    @listener = type.onUpdate do |t, resolved|
      import static org.mirah.util.Comparisons.*
      if areSame(t, delegate.type)
        delegate.resolved(resolved)
      end
    end
#   resolved(nil) unless type.isResolved
  end

  def dump(out)
    out.printFuture(@type)
  end

  def getComponents
    {target: @type}
  end
end
