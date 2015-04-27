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

$ExtensionsRegistration[['int']]
class IntExtensions
  macro def times(block:Block)
    i = if block.arguments && block.arguments.required_size() > 0
      block.arguments.required(0).name.identifier
    else
      gensym
    end
    last = gensym
    quote {
      while `i` < `last`
        init { `i` = 0; `last` = `@call.target`}
        post { `i` = `i` + 1 }
        `block.body`
      end
    }
  end

  macro def upto(n, block:Block)
    i = if block.arguments && block.arguments.required_size() > 0
      block.arguments.required(0).name.identifier
    else
      gensym
    end
    last = gensym
    quote {
      while `i` <= `last`
        init { `i` = `@call.target`; `last` = `n`}
        post { `i` = `i` + 1 }
        `block.body`
      end
    }
  end

  macro def downto(n, block:Block)
    i = if block.arguments && block.arguments.required_size() > 0
      block.arguments.required(0).name.identifier
    else
      gensym
    end
    last = gensym
    quote {
      while `i` >= `last`
        init { `i` = `@call.target`; `last` = `n`}
        post { `i` = `i` - 1 }
        `block.body`
      end
    }
  end
end
