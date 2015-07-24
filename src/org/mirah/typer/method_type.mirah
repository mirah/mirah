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

# The type of a method.
# It includes both the return type and the argument types, so it should not
# directly be used as a ResolvedType even though it implements the interface.
# Usually you want to use the return type instead.
class MethodType
  implements ResolvedType
  # TODO should this include the defining class?
  def initialize(name:String, parameterTypes:List, returnType:ResolvedType, isVararg:boolean)
    @name = name
    @parameterTypes = parameterTypes
    @returnType = returnType
    @isVararg = isVararg
    # parameterTypes.each do |p|
    #   unless p.kind_of?(ResolvedType)
    #     raise IllegalArgumentException.new("#{p} is not a ResolvedType")
    #   end
    # end
    raise IllegalArgumentException if parameterTypes.any? {|p| p && ResolvedType(p).isBlock }
  end

  def name
    @name
  end

  def parameterTypes:List
    @parameterTypes
  end

  def returnType:ResolvedType
    @returnType
  end

  def isVararg:boolean
    @isVararg
  end

  def widen(other:ResolvedType):ResolvedType
    import static org.mirah.util.Comparisons.*
    return self if areSame(self, other)
    raise IllegalArgumentException
  end

  def assignableFrom(other:ResolvedType):boolean
    import static org.mirah.util.Comparisons.*
    areSame(self, other)
  end

  def isMeta:boolean
    false
  end

  def isInterface:boolean
    false
  end

  def isError:boolean
    false
  end

  def matchesAnything:boolean
    false
  end

  def toString:String
    "<MethodType: name=#{@name} #{@parameterTypes} : #{@returnType}>"
  end

  def isFullyResolved:boolean
    true
  end
end
