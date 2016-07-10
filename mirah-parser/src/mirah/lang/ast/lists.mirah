package mirahparser.lang.ast

class HashEntryList < NodeImpl
  init_list HashEntry
end

class NodeList < NodeImpl
  init_list Node
end

class TypeNameList < NodeImpl
  init_list TypeName
end

class AnnotationList < NodeImpl
  init_list Annotation
end

class RescueClauseList < NodeImpl
  init_list RescueClause
end

class StringPieceList < NodeImpl
  init_list StringPiece
end

class RequiredArgumentList < NodeImpl
  init_list RequiredArgument
end

class OptionalArgumentList < NodeImpl
  init_list OptionalArgument
end
