package org.mirah.builtins

import org.mirah.macros.Compiler
import java.util.Collections

class Builtins
  def self.initialize_builtins(mirah:Compiler)
    mirah.type_system.extendClass('java.util.Map', MapExtensions.class)
    mirah.type_system.extendClass('java.lang.Object', ObjectExtensions.class)
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