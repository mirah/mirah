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

  def identifier: String
    obj = @object || @value
    identifierNode(obj).identifier
  end

  def identifierNode(obj: Object): Identifier
    if obj.kind_of?(Identifier)
      obj.as!(Identifier)
    elsif obj.kind_of?(Named)
      obj.as!(Named).name
    elsif obj.kind_of?(String)
      SimpleString.new(obj.as!(String))
    else
      raise UnsupportedOperationException, "#{obj} is not an Identifier"
    end
  end

  def typeref(obj=nil): TypeRef
    obj ||= @object || @value
    if obj.kind_of?(TypeRef)
      obj.as! TypeRef
    elsif obj.kind_of?(TypeName)
      obj.as!(TypeName).typeref
    elsif obj.kind_of?(Identifier)
      id = obj.as! Identifier
      TypeRefImpl.new(id.identifier, false, false, id.position)
    elsif obj.kind_of?(String)
      TypeRefImpl.new(obj.as!(String))
    else
      raise UnsupportedOperationException, "#{obj} does not name a type"
    end
  end

  def nodes: List
    value = self.object
    return Collections.emptyList if value.nil?
    if value.kind_of?(Iterable) && !value.kind_of?(Hash) && !value.kind_of?(Node)
      values = ArrayList.new
      value.as!(Iterable).each { |o| values.add(nodeValue(o))}
      values
    else
      Collections.singletonList(nodeValue(value))
    end
  end

  def node: Node
    return nodeValue(object)
  end

  def nodeValue(value: Object)
    return nil if value.nil?
    return value.as!(Node) if value.kind_of?(Node)
    return Fixnum.new(position, value.as!(Integer).intValue) if value.kind_of?(Integer)
    unless value.kind_of?(String)
      raise IllegalArgumentException, "Bad unquote value for node #{value}  (#{value.getClass})"
    end

    strvalue = value.as!(String)
    if '@'.equals(strvalue.substring(0, 1))
      FieldAccess.new(position, SimpleString.new(position, strvalue.substring(1))).as!(Node)
    else
      strnode = SimpleString.new(position, strvalue)
      if Character.isUpperCase(strvalue.charAt(0)) || strvalue.indexOf('.') >= 0
        Constant.new(position, strnode).as!(Node)
      else
        LocalAccess.new(position, strnode)
      end
    end
  end

  def arguments: Arguments
    if object.kind_of?(Arguments) || object.nil?
      object.as! Arguments
    elsif object.kind_of?(List)
      args = Arguments.empty(position)
      object.as!(List).each do |o|
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
  def add_arg(args: Arguments, node: Node)
    if node.kind_of?(OptionalArgument)
      args.optional.add(node.as!(OptionalArgument))
    elsif node.kind_of?(RestArgument)
      # TODO check for multiples?
      args.rest = node.as!(RestArgument)
    elsif node.kind_of?(BlockArgument)
      args.block = node.as!(BlockArgument)
    else
      arg = node.as!(RequiredArgument)
      if args.required2.size == 0 && args.rest.nil? && args.optional.size == 0
        args.required.add(arg)
      else
        args.required2.add(arg)
      end
    end
    args
  end

  def arg_item(object: Object): Node
    if object.kind_of?(RequiredArgument) ||
       object.kind_of?(OptionalArgument) ||
       object.kind_of?(RestArgument)     ||
       object.kind_of?(BlockArgument)
      object.as!(Node)
    elsif object.kind_of?(Identifier)
      id = object.as! Identifier
      RequiredArgument.new(id.position, id, nil)
    elsif object.kind_of?(String)
      RequiredArgument.new(position, SimpleString.new(position, object.as!(String)), nil)
    elsif object.kind_of?(List)
      l = object.as!(List)
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
    child java_doc: Node
  end

  def initialize(name: Identifier, arguments: Arguments, body: List, annotations: List)
    initialize(name, arguments, body, annotations, Node(nil))
  end

  def initialize(p:Position, name: Identifier, arguments: Arguments, body: List, annotations: List)
    initialize(p, name, arguments, body, annotations, Node(nil))
  end
end