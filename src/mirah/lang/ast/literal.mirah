# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
# All contributing project authors may be found in the NOTICE file.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
package mirahparser.lang.ast

import java.util.List

class Array < NodeImpl
  init_node do
    child_list values: Node
  end
end

class Fixnum < NodeImpl  # Should we rename this?
  init_literal 'long'
end

class Float < NodeImpl
  init_literal 'double'
end

class CharLiteral < NodeImpl
  init_literal 'int'
end

class Hash < NodeImpl
  init_list HashEntry
end

class HashEntry < NodeImpl
  init_node do
    child key: Node
    child value: Node
  end
end

interface StringPiece < Node do
end

class SimpleString < NodeImpl
  implements TypeName, StringPiece, Identifier
  init_literal String

  def identifier
    value
  end

  def typeref:TypeRef
    TypeRef(TypeRefImpl.new(@value, false, false, position))
  end
end

class StringConcat < NodeImpl
  init_node do
    child_list strings: StringPiece
  end
  def addAll(sc:StringConcat)
    addAll(sc.strings)
  end
  def addAll(strings:StringPieceList)
    until strings.size == 0
      @strings.add(strings.remove(0))
    end
  end
  def add(piece:StringPiece)
    @strings.add(piece)
  end
end

class StringEval < NodeImpl
  implements StringPiece
  init_node do
    child value: Node
  end
end

class Regex < NodeImpl
  init_node do
    child_list strings:StringPiece
    child options: Identifier
  end
end

# Is this used?
class Symbol < NodeImpl
  init_literal String
end

class Boolean < NodeImpl
  init_literal 'boolean'
end

class Null < NodeImpl  # Shouldn't this be called Nil?
  init_node
end

class ImplicitNil < Null
  init_node
end

class Self < NodeImpl
  init_node
end

class ImplicitSelf < Self
  init_node
end