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

# Future for a local variable
class LocalFuture < AssignableTypeFuture
  def initialize(name:String, position:Position)
    super(position)
    @name = name
    self.error_message = "Undefined variable #{name}"
    @children = ArrayList.new
  end

  def checkAssignments
    super
    @parent.checkAssignments if @parent
  end

  def parent=(parent:LocalFuture)
    @parent = parent
    parent.addChild(self)
    me = self
    parent.onUpdate do |x, resolved|
      me.resolved(resolved)
    end
    checkAssignments
  end

  def addChild(child:LocalFuture)
    @children.add(child)
  end

  def hasDeclaration
    (@parent && @parent.hasDeclaration) || super
  end

  def declaredType
    (@parent && @parent.declaredType) || super
  end

  def assignedValues(includeParent, includeChildren, forceIncludeChildren = false)
    return super unless includeParent || includeChildren

    assignments = LinkedHashSet.new()
    if @parent && includeParent
      assignments.addAll(@parent.assignedValues(true, false))
    end

    assignments.addAll super

    if (forceIncludeChildren || assignments.size > 0) && includeChildren
      @children.each do |child|
        assignments.addAll(LocalFuture(child).assignedValues(false, true, true))
      end
    end

    Collection(assignments)
  end

  def toString
    "<#{getClass.getSimpleName} name=#{@name} #{@children}>"
  end
end

