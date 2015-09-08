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

$ExtensionsRegistration[['java.util.Map']]
class MapExtensions
  macro def [](key)
    quote { `@call.target`.get(`key`) }
  end

  macro def []=(key, value)
    wrapped_value = [value]
    quote { `@call.target`.put(`key`, `wrapped_value`) }
  end

  macro def empty?
    quote { `@call.target`.isEmpty }
  end

  macro def keys
    quote { `@call.target`.keySet }
  end

  # Iterates over each entry of this map, each time yielding the key and the value.
  macro def each(block:Block)
    entry  = gensym
    
    k_arg    = block.arguments.required(0)
    k        = k_arg.name.identifier
    k_getter = quote { `entry`.getKey   }
    k_type   = k_arg.type if k_arg.type
    k_getter = Cast.new(k_type.position, k_type, k_getter) if k_type

    v_arg    = block.arguments.required(1)
    v        = v_arg.name.identifier
    v_getter = quote { `entry`.getValue }
    v_type   = v_arg.type if v_arg.type
    v_getter = Cast.new(v_type.position, v_type, v_getter) if v_type

    quote do
      `@call.target`.entrySet.each do |`entry`|
        `k` = `k_getter`
        `v` = `v_getter`
        `block.body`
      end
    end
  end
  # TODO each
end
