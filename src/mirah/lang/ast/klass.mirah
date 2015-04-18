package mirahparser.lang.ast
import java.util.Collections
import java.util.List

# Note: com.sun.source.tree uses the same node for classes, interfaces, annotations, etc.
class ClassDefinition < NodeImpl
  implements Annotated, Named
  init_node do
    child name: Identifier
    child superclass: TypeName
    child_list body: Node
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

#
# A wish by the source code author that a field
#   should have a certain value (e.g. if it is static final)
#   should have certain annotations.
#
# The wish is expressed as a FieldAnnotationRequest node instead of a
# FieldDeclaration node, as current compiler code expects FieldDeclaration nodes
# to be synthesized by the compiler itself, not by the source code author
# or macros invoked by the author.
#
# FieldAnnotationRequest nodes are to be created by macros. Hence, they can be
# removed by a better implementation and just macros need to be changed.
#
class FieldAnnotationRequest < NodeImpl
  implements Annotated, Named
  init_node do
    child name: Identifier
    child value: Node
    child_list annotations: Annotation
  end
end

class FieldDeclaration < NodeImpl
  implements Annotated, Named
  init_node do
    child name: Identifier
    child type: TypeName
    child value: Node
    child_list annotations: Annotation
    attr_accessor isStatic: 'boolean'
  end
end

class FieldAssign < NodeImpl
  implements Annotated, Named, Assignment
  init_node do
    child name: Identifier
    child value: Node
    child_list annotations: Annotation
    attr_accessor isStatic: 'boolean'
  end

  def initialize(position:Position, name:Identifier, annotations:List, isStatic:boolean)
    initialize(position, name, Node(nil), annotations)
    self.isStatic = isStatic
  end
end

class FieldAccess < NodeImpl
  implements Named
  init_node do
    child name: Identifier
    attr_accessor isStatic: 'boolean'
  end

  def initialize(position:Position, name:Identifier, isStatic:boolean)
    initialize(position, name)
    self.isStatic = isStatic
  end
end

class Include < NodeImpl
  init_node do
    child_list includes: TypeName
  end
end

class Constant < NodeImpl
  implements Named, TypeName, Identifier
  init_node do
    child name: Identifier
    attr_accessor isArray: 'boolean'  # TODO This doesn't seem right
  end

  def identifier:String
    name.identifier
  end
  def typeref:TypeRef
    TypeRefImpl.new(name.identifier, @isArray, false, position)
  end
end

class Colon3 < Constant
  init_subclass(Constant)
  def typeref:TypeRef
    TypeRefImpl.new("::#{identifier}", false, false, position)
  end
end

class ConstantAssign < NodeImpl
  implements Annotated, Named, Assignment
  init_node do
    child name: Identifier
    child value: Node
    child_list annotations: Annotation
  end
end

class AttrAssign < NodeImpl
  implements Named, Assignment
  init_node do
    child target: Node
    child name: Identifier
    child value: Node
  end
end

class ElemAssign < NodeImpl
  implements Assignment
  init_node do
    child target: Node
    child_list args: Node
    child value: Node
  end
end