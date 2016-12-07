# Copyright (c) 2012-2015 The Mirah project authors. All Rights Reserved.
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

import mirah.lang.ast.*

# A TypeRef which is actually not statically defined, but which yields a TypeFuture.
# This is to allow macros to construct ASTs refering to a type even if that type is not (yet) resolved.
class TypeFutureTypeRef < NodeImpl
  implements TypeName,TypeRef
  
  attr_accessor type_future:TypeFuture
  
  def initialize(type_future:TypeFuture)
    self.type_future = type_future
  end
  
  def typeref:TypeRef
    self
  end
  
  def name:String
    raise UnsupportedOperationException
  end
  
  def isArray:boolean
    raise UnsupportedOperationException
  end
  
  def isStatic:boolean
    raise UnsupportedOperationException
  end
end
