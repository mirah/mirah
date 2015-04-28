# Copyright (c) 2015 The Mirah project authors. All Rights Reserved.
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
$ExtensionsRegistration[['java.util.Collection']]
class CollectionExtensions
  # returns true if is empty
  # an alias for isEmpty
  macro def empty?
    quote { `@call.target`.isEmpty }
  end

  macro def map(block:Block)
    x = if block.arguments && block.arguments.required_size() > 0
      block.arguments.required(0)
    else
      gensym
    end

    list = gensym
    result = gensym
    quote do
      `list` = `@call.target`
      `result` = java::util::ArrayList.new(`list`.size)
      `list`.each do |`x`|
        `result`.add(` [block.body] `)
      end
      `result`
    end
  end

  macro def select(block:Block)
    x      = block.arguments.required(0)
    list   = gensym
    result = gensym
    quote do
      `list`   = `@call.target`
      `result` = java::util::ArrayList.new(`list`.size)
      `list`.each do |`x`|
        if (` [block.body] `)
          `result`.add(`x.name.identifier`)
        end
      end
      `result`
    end
  end
end
