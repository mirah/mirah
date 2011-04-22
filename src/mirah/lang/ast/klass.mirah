package mirah.lang.ast

# Note: com.sun.source.tree uses the same node for classes, interfaces, annotations, etc.
class ClassDefinition < NodeImpl
  implements Annotated, Named
  init_node do
    child name: Identifier
    child superclass: TypeName
    child body: Node # NodeList?
    child_list interfaces: TypeName
    child_list annotations: Annotation
  end
end

class InterfaceDeclaration < ClassDefinition
  init_subclass(ClassDefinition)
end

# Is this necessary?
class ClosureDefinition < ClassDefinition
  init_subclass(ClassDefinition)
end

class FieldDeclaration < NodeImpl
  implements Annotated, Named
  init_node do
    child name: Identifier
    child type: TypeName
    child_list annotations: Annotation
  end
end

class FieldAssign < NodeImpl
  implements Annotated, Named
  init_node do
    child name: Identifier
    child value: Node
    child_list annotations: Annotation
  end
end

class FieldAccess < NodeImpl
  implements Named
  init_node do
    child name: Identifier
  end
end

class Include < NodeImpl
  init_node do
    child_list includes: TypeName
  end
end

class Constant < NodeImpl
  implements Named, TypeName
  init_node do
    child name: Identifier
    attr_accessor isArray: 'boolean'  # TODO This doesn't seem right
  end

  def typeref:TypeRef
    TypeRefImpl.new(name.identifier, @isArray, false, position)
  end
end