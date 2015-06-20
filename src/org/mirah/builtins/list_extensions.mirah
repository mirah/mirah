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
  
  # Note that this macro is shadowed by Java 1.8 java::util::List#sort(java.util.Comparator)
  # So if the compiler has the Java 1.8 bootclasspath available, it will not pick up this macro. 
  macro def sort!(comparator:Block)
    list = gensym
    quote do
      `list` = `@call.target`
#     java::util::Collections.sort(`list`,`comparator`)
      `Call.new(quote{java::util::Collections},SimpleString.new('sort'),[quote{`list`}],comparator)`
      `list`
    end
  end

  macro def sort(comparator:Block)
    list   = gensym
    result = gensym
    quote do
      `list` = `@call.target`
      `result` = java::util::ArrayList.new(`list`)
#     `result`.sort!(`comparator`)
      `Call.new(quote{`result`},SimpleString.new('sort!'),[],comparator)`
      `result`
    end
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
  
  # Returns first element of the list.
  # Because Mirah has Ruby syntax but Java semantics, in case the list is empty, nil is not returned, but an instance of java.lang.IndexOutOfBoundsException is raised. 
  macro def first()
    quote do
      `call.target`[0]
    end
  end
  
  # Returns last  element of the list.
  # Because Mirah has Ruby syntax but Java semantics, in case the list is empty, nil is not returned, but an instance of java.lang.IndexOutOfBoundsException is raised. 
  macro def last()
    quote do
      `call.target`[`call.target`.size()-1]
    end
  end
end
