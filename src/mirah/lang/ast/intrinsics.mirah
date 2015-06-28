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

import java.util.ArrayList
import java.util.Collections
import java.util.List

class Unquote < NodeImpl
  implements TypeName, Identifier
  init_node do
    child value: Node
    attr_accessor object: Object
  end

  def identifier:String
    obj = @object || @value
    identifierNode(obj).identifier
  end

  def identifierNode(obj:Object):Identifier
    if obj.kind_of?(Identifier)
      Identifier(obj)
    elsif obj.kind_of?(Named)
      Named(obj).name
    elsif obj.kind_of?(String)
      SimpleString.new(String(obj))
    else
      raise UnsupportedOperationException, "#{obj} is not an Identifier"
    end
  end

  def typeref(obj=nil):TypeRef
    obj ||= @object || @value
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
    if value.kind_of?(Iterable) && !value.kind_of?(Hash) && !value.kind_of?(Node)
      values = List(ArrayList.new)
      Iterable(value).each {|o| values.add(nodeValue(o))}
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
      Node(FieldAccess.new(position, SimpleString.new(position, strvalue.substring(1))))
    else
      strnode = SimpleString.new(position, strvalue)
      if Character.isUpperCase(strvalue.charAt(0)) || strvalue.indexOf('.') >= 0
        Node(Constant.new(position, strnode))
      else
        LocalAccess.new(position, strnode)
      end
    end
  end

  def arguments:Arguments
    if object.kind_of?(Arguments) || object.nil?
      Arguments(object)
    elsif object.kind_of?(List)
      args = Arguments.empty(position)
      List(object).each do |o|
        add_arg(args, arg_item(o))
      end
      args
    else
      args = Arguments.empty(position)
      add_arg(args, arg_item(object))
      args
    end
  end

#  private
  def add_arg(args:Arguments, node:Node)
    if node.kind_of?(OptionalArgument)
      args.optional.add(OptionalArgument(node))
    elsif node.kind_of?(RestArgument)
      # TODO check for multiples?
      args.rest = RestArgument(node)
    elsif node.kind_of?(BlockArgument)
      args.block = BlockArgument(node)
    else
      arg = RequiredArgument(node)
      if args.required2.size == 0 && args.rest.nil? && args.optional.size == 0
        args.required.add(arg)
      else
        args.required2.add(arg)
      end
    end
    args
  end

  def arg_item(object:Object):Node
    if object.kind_of?(RequiredArgument) || object.kind_of?(OptionalArgument) ||
        object.kind_of?(RestArgument) || object.kind_of?(BlockArgument)
      Node(object)
    elsif object.kind_of?(Identifier)
      id = Identifier(object)
      RequiredArgument.new(id.position, id, nil)
    elsif object.kind_of?(String)
      RequiredArgument.new(position, SimpleString.new(position, String(object)), nil)
    elsif object.kind_of?(List)
      l = List(object)
      nameobj = l.get(0)
      type = l.size > 1 ? typeref(l.get(1)) : nil
      name = identifierNode(nameobj)
      RequiredArgument.new(name.position, name, type)
    else
      raise IllegalArgumentException, "Bad unquote value for arg #{value} (#{value.getClass})"
    end
  end
end

class UnquoteAssign < NodeImpl
  implements Named, Assignment
  init_node do
    child unquote: Unquote
    child value: Node
  end
  def name:Identifier
    unquote
  end
end

class MacroDefinition < NodeImpl
  implements Named, Annotated
  init_node do
    child name: Identifier
    child arguments: Arguments
    child_list body: Node
    child_list annotations: Annotation
    attr_accessor isStatic: 'boolean'
  end
end