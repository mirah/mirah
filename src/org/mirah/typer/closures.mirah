# Copyright (c) 2012 The Mirah project authors. All Rights Reserved.
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

package org.mirah.typer

import mirah.lang.ast.*
import java.util.Collections

# This class transforms a Block into an anonymous class once the Typer has figured out
# the interface to implement (or the abstract superclass).
#
# Note: This is ugly. It depends on the internals of the JVM scope and jvm_bytecode classes,
# and the BindingReference node is a hack. This should really all be cleaned up.
class ClosureBuilder
  def initialize(typer:Typer)
    @typer = typer
    @types = typer.type_system
    @scoper = typer.scoper
  end
  
  def prepare(block:Block, parent_type:ResolvedType)
    enclosing_node = block.findAncestor {|node| node.kind_of?(MethodDefinition) || node.kind_of?(Script)}
    enclosing_body = if enclosing_node.kind_of?(MethodDefinition)
      MethodDefinition(enclosing_node).body
    else
      Script(enclosing_node).body
    end
    
    klass = build_class(block.position, parent_type)

    # TODO(ribrdb) binding
    parent_scope = @scoper.getScope(block)
    build_constructor(enclosing_body, klass, parent_scope)
    
    unless add_methods(klass, block)
      build_method(klass, block, parent_type)
    end
    
    # Now assign the parent scopes
    klass.body.each do |n|
      unless n.kind_of?(ConstructorDefinition)
        method = MethodDefinition(n)
        @scoper.addScope(method).parent = parent_scope
      end
    end

    # Infer the types
    enclosing_body.insert(0, klass)
    closure_type = @typer.infer(klass)
    
    target = makeTypeName(block.position, closure_type.resolve)
    Call.new(block.position, target, SimpleString.new("new"), [BindingReference.new], nil)
  end

  # Builds an anonymous class.
  def build_class(position:Position, parent_type:ResolvedType)
    interfaces = if (parent_type && parent_type.isInterface)
      [makeTypeName(position, parent_type)]
    else
      Collections.emptyList
    end
    superclass = if (parent_type.nil? || parent_type.isInterface)
      nil
    else
      makeTypeName(position, parent_type)
    end
    ClosureDefinition.new(position, nil, superclass, Collections.emptyList, interfaces, nil)
  end

  def makeTypeName(position:Position, type:ResolvedType)
    Constant.new(position, SimpleString.new(position, type.name))
  end

  # Copies MethodDefinition nodes from block to klass.
  # Returns true if any MethodDefinitions were found.
  def add_methods(klass:ClassDefinition, block:Block):boolean
    found_methods = false
    block.body_size.times do |i|
      node = block.body(i)
      # TODO warn if there are non method definition nodes
      # they won't be used at all currently--so it'd be nice to note that.
      if node.kind_of?(MethodDefinition)
        cloned = MethodDefinition(node.clone)
        klass.body.add(cloned)
        found_methods = true
      end
    end
    return found_methods
  end

  # Builds MethodDefinitions in klass for the abstrace methods in iface.
  def build_method(klass:ClassDefinition, block:Block, iface:ResolvedType)
    methods = @types.getAbstractMethods(iface)
    if methods.size != 1
      raise UnsupportedOperationException, "Multiple abstract methods in #{iface}"
    end
    methods.each do |_m|
      mtype = MethodType(_m)
      name = SimpleString.new(block.position, mtype.name)
      args = if block.arguments
        Arguments(block.arguments.clone)
      else
        Arguments.new(block.position, Collections.emptyList, Collections.emptyList, nil, Collections.emptyList, nil)
      end
      return_type = makeTypeName(block.position, mtype.returnType)
      method = MethodDefinition.new(block.position, name, args, return_type, nil, nil)
      method.body = NodeList(block.body.clone)
      klass.body.add(method)
    end
  end
  
  def build_constructor(enclosing_body:NodeList, klass:ClassDefinition, parent_scope:Scope):void
    parent_scope.binding_type ||= begin
      binding_klass = build_class(klass.position, nil)
      enclosing_body.insert(0, binding_klass)
      @typer.infer(binding_klass, true).resolve
    end
    binding_type_name = makeTypeName(klass.position, parent_scope.binding_type)
    args = Arguments.new(klass.position, [RequiredArgument.new(SimpleString.new('binding'), binding_type_name)],
                         Collections.emptyList, nil, Collections.emptyList, nil)
    body = FieldAssign.new(SimpleString.new('binding'), LocalAccess.new(SimpleString.new('binding')), nil)
    constructor = ConstructorDefinition.new(SimpleString.new('initialize'), args, SimpleString.new('void'), [body], nil)
    klass.body.add(constructor)
  end
end