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

import org.mirah.macros.anno.ExtensionsRegistration

$ExtensionsRegistration[['java.lang.Iterable']]
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
  
  # Iterates over each element of the Iterable, yielding each time both the element and the index in the Iterable.
  macro def each_with_index(block:Block)
    value = block.arguments.required(0)
    count = block.arguments.required(1).name.identifier
    quote do
      `count` = 0
      `@call.target`.each do |`value`|
        `block.body`
        `count` = `count`+1 
      end
    end
  end

  macro def zip(other:Node, block:Block)
    if block.arguments && block.arguments.required_size() > 0
      arg = block.arguments.required(0)
      a = arg.name.identifier
      a_type = arg.type if arg.type
    else
      a = gensym
      a_type = TypeName(nil)
    end
    if block.arguments && block.arguments.required_size() > 1
      arg = block.arguments.required(1)
      b = arg.name.identifier
      b_type = arg.type if arg.type
    else
      b = gensym
      b_type = TypeName(nil)
    end    
    ait = gensym
    bit = gensym

    a_getter = quote { `ait`.next }
    if a_type
      a_getter = Cast.new(a_type.position, a_type, a_getter)
    end
    b_getter = quote { `bit`.next if `bit`.hasNext }
    if b_type
      b_getter = Cast.new(b_type.position, b_type, b_getter)
    end

    quote do
      while `ait`.hasNext
        init do
          `ait` = `@call.target`.iterator
          `bit` = `other`.iterator
        end
        pre do
          `a` = `a_getter`
          `b` = `b_getter`
        end
        `block.body`
      end
    end
  end
end
