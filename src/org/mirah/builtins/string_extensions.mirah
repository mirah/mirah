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

$ExtensionsRegistration[['java.lang.String']]
class StringExtensions
  macro def +(arg)
    quote { "#{`@call.target`}#{`arg`}" }
  end

  macro def include?(arg)
    quote { `@call.target`.contains(`arg`) }
  end

  macro def =~(arg)
    quote { `arg`.matcher(`@call.target`).find }
  end
  
  macro def match(arg)
    m = gensym
    quote do
      `m` = `arg`.matcher(`@call.target`)
      if `m`.find
        `m`
      else
        nil
      end
    end
  end
  
  # separate to to_i(), as to_i() (in order to maintain Ruby compatibility) could return a BigInteger,
  # while to_int() always returns an int.
  macro def to_int:int
    quote { Integer.parseInt(`@call.target`) }
  end
  
  # Iterates over each unicode codepoint of the String, optionally yielding an int.
  macro def each_codepoint(block:Block)
    target    = gensym
    offset    = gensym
    length    = gensym
    codepoint = (block.arguments && block.arguments.required_size() > 0) ? block.arguments.required(0).name.identifier : gensym
    quote do
      `target` = `@call.target` 
      `offset` = 0
      `length` = `target`.length
      while `offset` < `length`
        `codepoint` = `target`.codePointAt(`offset`)
        `block.body`
        `offset` = `offset` + Character.charCount(`codepoint`)
      end
    end
  end
end
