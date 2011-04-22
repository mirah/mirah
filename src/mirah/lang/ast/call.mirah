package mirah.lang.ast

class FunctionalCall < NodeImpl
  implements Named, TypeName
  init_node do
    child name: Identifier
    child_list parameters: Node
    child block: Node  # Should this be more specific?
  end

  def typeref:TypeRef
    TypeRefImpl.new(name.identifier, false, false, position)
  end
end

class Cast < NodeImpl
  init_node do
    child type: TypeName
    child value: Node
  end
end

class Call < NodeImpl
  implements Named, TypeName
  init_node do
    child target: Node
    child name: Identifier
    child_list parameters: Node
    child block: Node
  end

  def typeref:TypeRef
    return nil if parameters.size > 0
    return nil unless target.kind_of?(TypeName)
    target_typeref = TypeName(target).typeref
    return nil if target_typeref.nil?
    if '[]'.equals(name)
      return TypeRefImpl.new(target_typeref.name, true, false, position)
    else
      name = "#{target_typeref.name}.#{name}"
      return TypeRefImpl.new(name, false, false, position)
    end
  end
end

# This needs a better name. Maybe something like QualifiedName
class Colon2 < Call
  init_subclass(Call)
end

class ZSuper < NodeImpl
  init_node
end

class Super < NodeImpl  # < ZSuper?
  init_node do
    child_list parameters: Node
  end
end

class BlockPass < NodeImpl
  init_node do
    child value: Node
  end
end
