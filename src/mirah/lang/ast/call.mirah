package mirahparser.lang.ast

interface CallSite < Node, Named, TypeName do
  def name:Identifier; end
  def target:Node; end
  def parameters: NodeList; end
  def block:Block; end
  def block_set(block:Block):void; end
end

class FunctionalCall < NodeImpl
  implements Named, TypeName, CallSite
  init_node do
    child name: Identifier
    child_list parameters: Node
    child block: Block
  end

  def target:Node
    @target ||= ImplicitSelf.new(position)
  end

  def typeref:TypeRef
    TypeRefImpl.new(name.identifier, false, false, name.position)
  end
end

# An identifier with no parens or arguments - may be a variable local access or a call.
class VCall < NodeImpl
  implements Named, TypeName, CallSite, Identifier
  init_node do
    child name: Identifier
  end
  
  def identifier
    name.identifier
  end
  
  def typeref:TypeRef
    TypeRefImpl.new(name.identifier, false, false, name.position)
  end

  def target:Node
    @target ||= ImplicitSelf.new(position)
  end
  def parameters
    @parameters ||= NodeList.new(position)
  end
  def block:Block
    nil
  end
  def block_set(block)
    raise UnsupportedOperationException
  end
end

class Cast < NodeImpl
  init_node do
    child type: TypeName
    child value: Node
  end
end

class Call < NodeImpl
  implements Named, TypeName, CallSite
  init_node do
    child target: Node
    child name: Identifier
    child_list parameters: Node
    child block: Block
  end

  def typeref(maybeCast=false):TypeRef
    return nil if parameters.size > 1
    return nil if parameters.size == 1 && !maybeCast
    return nil unless target.kind_of?(TypeName)
    target_typeref = TypeName(target).typeref
    return nil if target_typeref.nil?
    position = PositionImpl.add(self.name.position, target_typeref.position)
    if '[]'.equals(self.name.identifier)
      return TypeRefImpl.new(target_typeref.name, true, false, position)
    else
      name = "#{target_typeref.name}.#{self.name.identifier}"
      return TypeRefImpl.new(name, false, false, position)
    end
  end
end

# This needs a better name. Maybe something like QualifiedName
class Colon2 < NodeImpl
  implements Named, TypeName
  init_node do
    child target: Node
    child name: Identifier
  end

  def typeref:TypeRef
    if target.kind_of?(TypeName)
      outerType = TypeName(target).typeref.name
      if outerType
        return TypeRefImpl.new("#{outerType}.#{name.identifier}", false, false, position)
      end
    end
    raise UnsupportedOperationException, "#{target} does not name a type"
  end
end

# TODO: Super and ZSuper should probably be CallSites
class ZSuper < NodeImpl
  init_node
end

class Super < NodeImpl  # < ZSuper?
  init_node do
    child_list parameters: Node
    child block: Node
  end
end

class BlockPass < NodeImpl
  init_node do
    child value: Node
  end
end
