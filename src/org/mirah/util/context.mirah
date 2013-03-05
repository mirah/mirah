package org.mirah.util

import mirah.lang.ast.*

# Container for compilation-global state
class Context
  def initialize
    @state = {}
  end
  
  def add(klass:Class, value:Object):void
    @state[klass] = klass.cast(value)
  rescue ClassCastException
	  raise ClassCastException, "#{value.getClass} is not a #{klass}"
  end
  
  def get(klass:Class)
    @state[klass]
  end
  
  macro def []=(klass:TypeName, value)
    quote { `@call.target`.add(`klass`.class, `value`) }
  end
  
  macro def [](klass:TypeName)
    Cast.new(@call.position, klass, quote { `@call.target`.get(`klass`.class) })
  end
end