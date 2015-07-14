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

# Future for the type of a method.
# Resolves to either a MethodType or an ErrorType.
class MethodFuture < BaseTypeFuture
  def initialize(name: String,
                 parameters: List,
                 returnType: AssignableTypeFuture,
                 vararg: boolean,
                 position: Position)
    super(position)
    @methodName = name
    @returnType = returnType
    @vararg = vararg
    mf = self

    #raise IllegalArgumentException if parameters.any? {|p| ResolvedType(p).isBlock}
    @returnType.onUpdate do |f, type|
      if type.isError
        mf.resolved(type)
      else
        mf.resolved(MethodType.new(name, parameters, type, mf.isVararg))
      end
    end
  end

  def resolve
    unless isResolved
      @returnType.resolve
    end
    super
  end

  def methodName
    @methodName
  end

  def isVararg
    @vararg
  end

  def returnType
    @returnType
  end

  def dump(out)
    out.write("returnType: ")
    out.printFuture(@returnType)
    super
  end

  def getComponents
    {returnType: @returnType}
  end
end
