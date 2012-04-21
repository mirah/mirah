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

package org.mirah.builtins

class IterableExtensions
  macro def each(block:Block)
    if block.arguments && block.arguments.required_size() > 0
      arg = block.arguments.required(0)
      name = arg.name.identifier
      type = arg.type if arg.type
    else
      name = gensym
      type = TypeName(nil)
    end
    it = gensym
    
    getter = quote { `it`.next }
    if type
      getter = Cast.new(type.position, type, getter)
    end
    
    quote do
      while `it`.hasNext
        init {`it` = `@call.target`.iterator}
        pre {`name` = `getter`}
        `block.body`
      end
    end
  end
end