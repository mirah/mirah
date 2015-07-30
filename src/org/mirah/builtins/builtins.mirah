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

package org.mirah.builtins

import org.mirah.typer.TypeSystem
import java.util.Collections

class Builtins
  def self.initialize_builtins(type_system:TypeSystem)
    if self.builtins_enabled 
      type_system.extendClass('java.util.Collection', Class.forName("org.mirah.builtins.CollectionExtensions"))
      type_system.extendClass('java.util.Map', Class.forName("org.mirah.builtins.MapExtensions"))
      type_system.extendClass('java.util.List', Class.forName("org.mirah.builtins.ListExtensions"))
      type_system.extendClass('java.lang.Object', Class.forName("org.mirah.builtins.ObjectExtensions"))
      type_system.extendClass('java.lang.Iterable', Class.forName("org.mirah.builtins.EnumerableExtensions"))
      type_system.extendClass('java.lang.Iterable', Class.forName("org.mirah.builtins.IterableExtensions"))
      type_system.extendClass('java.lang.String', Class.forName("org.mirah.builtins.StringExtensions"))
      type_system.extendClass('java.lang.StringBuilder', Class.forName("org.mirah.builtins.StringBuilderExtensions"))
  
      type_system.extendClass('java.util.concurrent.locks.Lock', Class.forName("org.mirah.builtins.LockExtensions"))
      type_system.extendClass('java.util.regex.Matcher', Class.forName("org.mirah.builtins.MatcherExtensions"))
  
      type_system.extendClass('int', Class.forName("org.mirah.builtins.IntExtensions"))
      type_system.extendClass('byte', Class.forName("org.mirah.builtins.NumberExtensions"))
      type_system.extendClass('short', Class.forName("org.mirah.builtins.NumberExtensions"))
      type_system.extendClass('int', Class.forName("org.mirah.builtins.NumberExtensions"))
      type_system.extendClass('long', Class.forName("org.mirah.builtins.NumberExtensions"))
      type_system.extendClass('float', Class.forName("org.mirah.builtins.NumberExtensions"))
      type_system.extendClass('double', Class.forName("org.mirah.builtins.NumberExtensions"))
    end
  end
  
  def self.builtins_enabled
    !"false".equals(System.getProperty('org.mirah.builtins.enabled'))
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
