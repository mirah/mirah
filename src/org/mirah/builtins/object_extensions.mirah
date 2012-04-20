package org.mirah.builtins

class ObjectExtensions
  macro def puts(node)
    quote {System.out.println(`node`)}
  end
  
  macro def print(node)
    quote {System.out.print(`node`)}
  end
end