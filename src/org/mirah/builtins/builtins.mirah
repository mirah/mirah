package org.mirah.builtins

import org.mirah.macros.Compiler

class Builtins
  def self.initialize_builtins(mirah:Compiler)
    mirah.type_system.extendClass('java.lang.Object', ObjectExtensions.class)
    mirah.type_system.extendClass('java.util.Map', MapExtensions.class)
  end
  
  macro def newHash(hash:Hash)
    map = gensym
    capacity = int(hash.size * 0.84)
    capacity = 16 if capacity < 16
    
    block = quote do
      `map` = java::util::HashMap.new(`Fixnum.new(capacity)`)
      `map`.put(key, value)
      `map`
    end
    result = block.remove(2)
    put_template = block.remove(1)
    i = 0
    while i < hash.size
      block.add(put_template)
      put = Call(block.get(i + 1))
      entry = hash.get(i)
      put.parameters.set(0, entry.key)
      put.parameters.set(1, entry.value)
    end
    block.add(result)
    block
  end
end