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
import mirah.lang.ast.Position


class AssignmentFuture < BaseTypeFuture
  def initialize(variable:AssignableTypeFuture, value:TypeFuture, position:Position)
    super(position)
    @variable = variable
    @value = value
    assignment = self
    TypeFuture(@variable).onUpdate do |x, resolved|
      assignment.checkCompatibility
    end
  end

  def resolve
    unless isResolved
      resolved(@value.resolve)
    end
    super
  end
  
  def checkCompatibility:void
    resolved_value = @value.isResolved ? @value.resolve : nil
    resolved_variable = @variable.isResolved ? @variable.resolve : nil
    if resolved_value
      if resolved_value.isError
        resolved(resolved_value)
      elsif resolved_variable
        if resolved_variable.assignableFrom(resolved_value)
          resolved(resolved_value)
        elsif resolved_variable.isError
          resolved(resolved_variable)
        else
          resolved(@variable.incompatibleWith(resolved_value, position))
        end
      end
    end
  end
end