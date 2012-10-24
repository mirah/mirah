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

import org.mirah.macros.Compiler
import java.util.Collections

class Builtins
  def self.initialize_builtins(mirah:Compiler)
    mirah.type_system.extendClass('java.util.Map', MapExtensions.class)
    mirah.type_system.extendClass('java.util.List', ListExtensions.class)
    mirah.type_system.extendClass('java.lang.Object', ObjectExtensions.class)
    mirah.type_system.extendClass('java.lang.Iterable', EnumerableExtensions.class)
    mirah.type_system.extendClass('java.lang.Iterable', IterableExtensions.class)
    mirah.type_system.extendClass('int', IntExtensions.class)

    mirah.type_system.extendClass('byte', NumberExtensions.class)
    mirah.type_system.extendClass('short', NumberExtensions.class)
    mirah.type_system.extendClass('int', NumberExtensions.class)
    mirah.type_system.extendClass('long', NumberExtensions.class)
    mirah.type_system.extendClass('float', NumberExtensions.class)
    mirah.type_system.extendClass('double', NumberExtensions.class)
  end

  macro def newHash(hash:Hash)
    map = gensym
    capacity = int(hash.size * 0.84)
    capacity = 16 if capacity < 16

    block = quote do
      `map` = java::util::HashMap.new(`Fixnum.new(capacity)`)
      `map`.put()
      `map`
    end
    result = block.remove(2)
    put_template = block.remove(1)
    i = 0
    while i < hash.size
      entry = hash.get(i)
      put = Call(put_template.clone)
      put.position = entry.position
      put.parameters.add(entry.key)
      put.parameters.add(entry.value)
      block.add(put)
      i += 1
    end
    block.add(result)
    NodeList.new(hash.position, [block])
  end
end
