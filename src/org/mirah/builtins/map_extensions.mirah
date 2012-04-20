package org.mirah.builtins

class MapExtensions
  macro def [](key)
    quote { `@call.target`.get(`key`) }
  end

  macro def []=(key, value)
    quote { `@call.target`.put(`key`, `value`) }
  end

  macro def empty?
    quote { `@call.target`.isEmpty }
  end

  macro def keys
    quote { `@call.target`.keySet }
  end
end