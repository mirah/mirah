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

package org.mirah.jvm.model

import java.util.concurrent.locks.ReentrantLock
import javax.lang.model.type.DeclaredType
import javax.lang.model.type.TypeMirror
import org.mirah.jvm.mirrors.MirrorProxy

class Cycle implements DeclaredType
  attr_accessor target:DeclaredType

  def initialize
    @lock = ReentrantLock.new
    @depth = 0
  end

  def asElement
    @target.asElement
  end

  def getEnclosingType
    @target.getEnclosingType
  end

  def getTypeArguments
    @target.getTypeArguments
  end

  def getKind
    @target.getKind
  end

  def accept(v, p)
    @target.accept(v, p)
  end

  def hashCode
    @target.hashCode
  end

  def equals(other)
    @target.equals(other)
  end

  def toString
    @lock.lock
    begin
      @depth += 1
      if @depth > 2
        "..."
      else
        @target.toString
      end
    ensure
      @depth -= 1
      @lock.unlock
    end
  end
end