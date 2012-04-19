package org.mirah.builtins

import org.mirah.macros.Compiler

class Builtins
  def self.initialize_builtins(mirah:Compiler)
    mirah.type_system.extendClass('java.lang.Object', ObjectExtensions.class)
  end
end