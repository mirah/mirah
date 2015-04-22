# Copyright (c) 2012-2014 The Mirah project authors. All Rights Reserved.
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
import java.util.logging.Logger
import java.util.Collections
import java.util.LinkedHashMap
import java.util.List
import java.util.Map.Entry
import java.util.ArrayList
import java.io.File



import org.mirah.jvm.mirrors.MirrorScope
import org.mirah.macros.MacroBuilder


interface ClosureBuilderer
  def insert_closure(block: Block, parent_type: ResolvedType): TypeFuture; end
  def add_todo(block: Block, parent_type: ResolvedType): void; end
  def finish: void; end
end

# This class transforms a Block into an anonymous class once the Typer has figured out
# the interface to implement (or the abstract superclass).
#
# Note: This is ugly. It depends on the internals of the JVM scope and jvm_bytecode classes,
# and the BindingReference node is a hack. This should really all be cleaned up.
class ClosureBuilder
  implements ClosureBuilderer
  # finish is a noop here
  def finish; end

  def add_todo block, parent_type

    new_scope = @typer.addNestedScope block
    @typer.logger.fine "block is closure with scope #{new_scope}"
    @typer.infer(block.arguments) if block.arguments
    unless parent_type.isError || block.parent.nil?
      insert_closure block, parent_type
    end
  end

  def self.initialize: void
    @@log = Logger.getLogger(ClosureBuilder.class.getName)
  end

  def initialize(typer: Typer)
    @typer = typer
    @types = typer.type_system
    @scoper = typer.scoper
  end

  def insert_closure(block: Block, parent_type: ResolvedType)
    # TODO: This will fail if the block's class changes.
    new_node = prepare_regular_closure(block, parent_type)

    parent = CallSite(block.parent)
    replace_block_with_closure_in_call parent, block, new_node
    infer(new_node)
  end

  # creates closure class, inserts it
  # returns Call Node that is the instantiation of the closure
  def prepare(block: Block, parent_type: ResolvedType): Call
    Call(prepare_regular_closure(block, parent_type))
  end

  def prepare_regular_closure(block: Block, parent_type: ResolvedType): Node
    parent_scope = get_scope block
    klass = build_closure_class block, parent_type, parent_scope
    
    if contains_methods(block)
      copy_methods(klass, block, parent_scope)
    else
      build_method(klass, block, parent_type, parent_scope)
    end
    new_closure_call_node(block, klass)
  end

  def replace_block_with_closure_in_call(parent: CallSite, block: Block, new_node: Node): void
    if block == parent.block
      parent.block = nil
      parent.parameters.add(new_node)
    else
      new_node.setParent(nil)
      parent.replaceChild(block, new_node)
    end
  end

  def find_enclosing_body block: Block
    enclosing_node = find_enclosing_node block
    get_body enclosing_node
  end

  def get_body node: Node
    if node.kind_of?(MethodDefinition)
      MethodDefinition(node).body
    else
      Script(node).body
    end
  end

  def find_enclosing_node block: Node
    block.findAncestor {|node| node.kind_of?(MethodDefinition) || node.kind_of?(Script)}
  end

  def temp_name_from_outer_scope block: Node,  scoped_name: String
    class_or_script = block.findAncestor {|node| node.kind_of?(ClassDefinition) || node.kind_of?(Script)}
    outer_name = if class_or_script.kind_of? ClassDefinition
                   ClassDefinition(class_or_script).name.identifier
                 else
                   source_name = class_or_script.position.source.name || 'DashE'
                   id = ""
                   File.new(source_name).getName.
                     replace("\.duby|\.mirah", "").
                     split("[_-]").each do |word|
                       id += word.substring(0,1).toUpperCase + word.substring(1)
                     end
                   id
                  end
    get_scope(class_or_script).temp "#{outer_name}$#{scoped_name}"
  end

  def build_closure_class block: Block, parent_type: ResolvedType, parent_scope: Scope
    klass = build_class(block.position, parent_type, temp_name_from_outer_scope(block, "Closure"))
    enclosing_body = find_enclosing_body block

    parent_scope.binding_type ||= begin
                                    name = temp_name_from_outer_scope(klass, "Binding")
                                    @@log.fine("building binding #{name}")
                                    binding_klass = build_class(klass.position,
                                                                nil,
                                                                name)
                                    insert_into_body enclosing_body, binding_klass
                                    infer(binding_klass).resolve
                                  end
    binding_type_name = makeTypeName(klass.position, parent_scope.binding_type)

    build_constructor(enclosing_body, klass, binding_type_name)


    insert_into_body enclosing_body, klass
    klass
  end

  def get_scope block: Node
    @scoper.getScope(block)
  end

  def new_closure_call_node(block: Block, klass: Node): Call
    closure_type = infer(klass)
    target = makeTypeName(block.position, closure_type.resolve)
    Call.new(block.position, target, SimpleString.new("new"), [BindingReference.new], nil)
  end

  # Builds an anonymous class.
  def build_class(position: Position, parent_type: ResolvedType, name:String=nil)
    interfaces = if (parent_type && parent_type.isInterface)
                    @@log.fine "making anon class w/ interface type #{parent_type}"
                   [makeTypeName(position, parent_type)]
                 else
                   Collections.emptyList
                 end
    superclass = if (parent_type.nil? || parent_type.isInterface)
                   nil
                 else
                   makeTypeName(position, parent_type)
                 end
    constant = nil
    constant = Constant.new(position, SimpleString.new(position, name)) if name
    ClosureDefinition.new(position, constant, superclass, Collections.emptyList, interfaces, nil, nil)
  end

  def makeTypeName(position: Position, type: ResolvedType)
    Constant.new(position, SimpleString.new(position, type.name))
  end

  def makeTypeName(position: Position, type: ClassDefinition)
    Constant.new(position, SimpleString.new(position, type.name.identifier))
  end

  # Copies MethodDefinition nodes from block to klass.
  def copy_methods(klass: ClassDefinition, block: Block, parent_scope: Scope): void
    block.body_size.times do |i|
      node = block.body(i)
      # TODO warn if there are non method definition nodes
      # they won't be used at all currently--so it'd be nice to note that.
      if node.kind_of?(MethodDefinition)
        cloned = MethodDefinition(node.clone)
        set_parent_scope cloned, parent_scope
        klass.body.add(cloned)
      end
    end
  end

  # Returns true if any MethodDefinitions were found.
  def contains_methods(block: Block): boolean
    block.body_size.times do |i|
      node = block.body(i)
      return true if node.kind_of?(MethodDefinition)
    end
    return false
  end

  # Builds MethodDefinitions in klass for the abstract methods in iface.
  def build_method(klass: ClassDefinition, block: Block, iface: ResolvedType, parent_scope: Scope):void
    methods = @types.getAbstractMethods(iface)
    if methods.size == 0
      @@log.warning("No abstract methods in #{iface}")
      return
    elsif methods.size > 1
      raise UnsupportedOperationException, "Multiple abstract methods in #{iface}: #{methods}"
    end
    methods.each do |_m|
      mtype = MethodType(_m)
      name = SimpleString.new(block.position, mtype.name)
      args = if block.arguments
               Arguments(block.arguments.clone)
             else
               Arguments.new(block.position, Collections.emptyList, Collections.emptyList, nil, Collections.emptyList, nil)
             end
      while args.required.size < mtype.parameterTypes.size
        arg = RequiredArgument.new(block.position, SimpleString.new("arg#{args.required.size}"), nil)
        args.required.add(arg)
      end
      return_type = makeTypeName(block.position, mtype.returnType)
      method = MethodDefinition.new(block.position, name, args, return_type, nil, nil, nil)
      method.body = NodeList(block.body.clone)

      set_parent_scope method, parent_scope

      klass.body.add(method)
    end
  end

  def build_constructor(enclosing_body: NodeList, klass: ClassDefinition, binding_type_name: Constant): void
    args = Arguments.new(klass.position,
                         [RequiredArgument.new(SimpleString.new('binding'), binding_type_name)],
                         Collections.emptyList,
                         nil,
                         Collections.emptyList,
                         nil)
    body = FieldAssign.new(SimpleString.new('binding'), LocalAccess.new(SimpleString.new('binding')), nil, nil)
    constructor = ConstructorDefinition.new(SimpleString.new('initialize'), args, SimpleString.new('void'), [body], nil, nil)
    klass.body.add(constructor)
  end

  def insert_into_body enclosing_body: NodeList, klass: ClassDefinition
    enclosing_body.insert(0, klass)
  end

  def infer node: Node
    @typer.infer node
  end

  def set_parent_scope method: MethodDefinition, parent_scope: Scope
    @scoper.addScope(method).parent = parent_scope
  end
end
