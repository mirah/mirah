package org.mirah.jvm.types

import org.mirah.typer.ResolvedType

interface JVMType < ResolvedType
  def internal_name:String; end
  def class_id:String; end
end