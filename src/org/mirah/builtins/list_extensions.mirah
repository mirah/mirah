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

class ListExtensions
  macro def [](index)
    quote { `@call.target`.get `index` }
  end

  macro def []=(index, value)
    quote { `@call.target`.add `index`, `value` }
  end
  
  macro def sort!(comparator)
    list = gensym
    quote do
      `list` = `@call.target`
      java::util::Collections.sort(`list`,`comparator`)
      `list`
    end
  end

  macro def sort(comparator)
    list   = gensym
    result = gensym
    quote do
      `list` = `@call.target`
      `result` = java::util::ArrayList.new(`list`)
      `result`.sort!(`comparator`)
      `result`
    end
  end
  
  macro def sort!()
    list = gensym
    quote do
      `list` = `@call.target`
      java::util::Collections.sort(`list`)
      `list`
    end
  end

  macro def sort()
    list   = gensym
    result = gensym
    quote do
      `list` = `@call.target`
      `result` = java::util::ArrayList.new(`list`)
      `result`.sort!
      `result`
    end
  end
end
