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

class Unquote < NodeImpl
  implements TypeName, Identifier
  init_node do
    child value: Node
    attr_accessor object: Object
  end

  def identifier:String
    obj = @object || @value
    if obj.kind_of?(Identifier)
      Identifier(obj).identifier
    elsif obj.kind_of?(String)
      String(obj)
    else
      raise UnsupportedOperationException, "#{obj} is not an Identifier"
    end
  end

  def typeref:TypeRef
    obj = @object || @value
    if obj.kind_of?(TypeRef)
      TypeRef(obj)
    elsif obj.kind_of?(TypeName)
      TypeName(obj).typeref
    elsif obj.kind_of?(Identifier)
      id = Identifier(obj)
      TypeRefImpl.new(id.identifier, false, false, id.position)
    elsif obj.kind_of?(String)
      TypeRefImpl.new(String(obj))
    else
      raise UnsupportedOperationException, "#{obj} does not name a type"
    end
  end

  def nodes:List
    value = self.object
    return Collections.emptyList if value.nil?
    if value.kind_of?(List)
      values = List(ArrayList.new)
      List(value).each {|o| values.add(nodeValue(o))}
      values
    else
      Collections.singletonList(nodeValue(value))
    end
  end

  def node:Node
    return nodeValue(object)
  end

  def nodeValue(value:Object)
    return nil if value.nil?
    return Node(value) if value.kind_of?(Node)
    return Fixnum.new(position, Integer(value).intValue) if value.kind_of?(Integer)
    unless value.kind_of?(String)
      raise IllegalArgumentException, "Bad unquote value for node #{value}  (#{value.getClass})"
    end
    strvalue = String(value)
    if '@'.equals(strvalue.substring(0, 1))
      FieldAccess.new(position, SimpleString.new(position, strvalue.substring(1)))
    else
      strnode = SimpleString.new(position, strvalue)
      if Character.isUpperCase(strvalue.charAt(0)) || strvalue.indexOf('.') >= 0
        Constant.new(position, strnode)
      else
        LocalAccess.new(position, strnode)
      end
    end
  end
end

class UnquoteAssign < NodeImpl
  implements Named, Assignment
  init_node do
    child name: Unquote
    child value: Node
  end
end

class MacroDefinition < NodeImpl
  implements Named
  init_node do
    child name: Identifier
    child arguments: NodeList
    child body: Node
  end
end