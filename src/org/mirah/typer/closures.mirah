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
import java.util.List
import java.util.ArrayList
import java.io.File

# This class transforms a Block into an anonymous class once the Typer has figured out
# the interface to implement (or the abstract superclass).
#
# Note: This is ugly. It depends on the internals of the JVM scope and jvm_bytecode classes,
# and the BindingReference node is a hack. This should really all be cleaned up.
class ClosureBuilder
  def initialize(typer: Typer)
    @typer = typer
    @types = typer.type_system
    @scoper = typer.scoper
  end

  def insert_closure(block: Block, parent_type: ResolvedType)
    # TODO: This will fail if the block's class changes.
    new_node =  if has_non_local_return block
                  prepare_non_local_return_closure(block, parent_type)
                else
                  prepare_regular_closure(block, parent_type)
                end

    parent = CallSite(block.parent)
    replace_block_with_closure_in_call parent, block, new_node
    infer(new_node)
  end

  def prepare(block: Block, parent_type: ResolvedType): Node
    prepare_regular_closure block, parent_type
  end

  def prepare_non_local_return_closure(block: Block, parent_type: ResolvedType): Node
    # generates closure classes, AND an exception type
    # and replaces the closure call with something like this:
    #
    # class MyNonLocalReturn < Throwable
    #   def initialize(return_value:`method return type`); @return_value = return_value; end
    #   def return_value; @return_value; end
    # end
    # begin
    #   call { raise MyNonLocalReturn, `value` }
    # rescue MyNonLocalReturn => e
    #   return e.return_value
    # end
    enclosing_node = find_enclosing_node block
    return_type = if enclosing_node.kind_of? MethodDefinition
                    methodType = infer(enclosing_node)
                    MethodFuture(methodType).returnType
                  elsif enclosing_node.kind_of? Script
                    future = AssignableTypeFuture.new block.position
                    future.assign(infer(enclosing_node), block.position)
                    future
                  end
    nlr_klass = define_nlr_exception block
    block = convert_returns_to_raises block, nlr_klass, return_type
    new_node = nlr_prepare block, parent_type, nlr_klass
    resolved = return_type.resolve

    raise "Unable to determine method return type before generating closure including non local return" unless resolved

    enclosing_body = get_body(enclosing_node)
    node_in_body = block.findAncestor { |node| node.parent.kind_of? NodeList }
    new_call = wrap_with_rescue block, nlr_klass, node_in_body, resolved
    node_in_body.parent.replaceChild node_in_body, new_call
    
    finish_nlr_exception block, nlr_klass, resolved
    insert_into_body enclosing_body, nlr_klass
    infer(nlr_klass)
    new_node
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

  def has_non_local_return(block: Block): boolean
    (!contains_methods(block)) && # TODO(nh): fix parser so !_ && _ works
    contains_return(block)
  end

  def define_nlr_exception(block: Block): ClosureDefinition
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
    exception_name = get_scope(class_or_script).temp "#{outer_name}$NLRException"
    nlr_klass = build_class block.position, @types.getBaseExceptionType.resolve, exception_name
    nlr_klass
  end

  def finish_nlr_exception(block: Node, nlr_klass: ClosureDefinition, return_value_type: ResolvedType)
    value_type_name = makeTypeName(block.position, return_value_type)
    required_constructor_arguments = unless void_type? return_value_type
                                       [RequiredArgument.new(SimpleString.new('return_value'), value_type_name)]
                                     else
                                       Collections.emptyList
                                     end
    args = Arguments.new(block.position,
                         required_constructor_arguments,
                         Collections.emptyList,
                         nil,
                         Collections.emptyList,
                         nil)
    body = unless void_type? return_value_type
             [FieldAssign.new(SimpleString.new('return_value'), LocalAccess.new(SimpleString.new('return_value')), nil)]
           else
             Collections.emptyList
           end
    constructor = ConstructorDefinition.new(SimpleString.new('initialize'), args, SimpleString.new('void'), body, nil)
    nlr_klass.body.add(constructor)

    unless void_type? return_value_type
      name = SimpleString.new(block.position, 'return_value')
      args = Arguments.new(block.position, Collections.emptyList, Collections.emptyList, nil, Collections.emptyList, nil)
      method = MethodDefinition.new(block.position, name, args, value_type_name, nil, nil)
      method.body = NodeList.new
      method.body.add Return.new(block.position, FieldAccess.new(SimpleString.new 'return_value'))

      nlr_klass.body.add method
    end
    nlr_klass
  end

  def nlr_prepare(block: Block, parent_type: ResolvedType, nlr_klass: Node): Node
    parent_scope = get_scope block
    klass = build_closure_class block, parent_type, parent_scope
    
    build_method(klass, block, parent_type, parent_scope)
  
    new_closure_call_node(block, klass)
  end

  def build_closure_class block: Block, parent_type: ResolvedType, parent_scope: Scope
    klass = build_class(block.position, parent_type)
    enclosing_body = find_enclosing_body block
    # TODO(ribrdb) binding
    build_constructor(enclosing_body, klass, parent_scope)


    insert_into_body enclosing_body, klass
    klass
  end

  def get_scope block: Node
    @scoper.getScope(block)
  end

  def wrap_with_rescue block: Node, nlr_klass: ClosureDefinition, call: Node, nlr_return_type: ResolvedType
    return_value = unless void_type? nlr_return_type
      Node(Call.new(block.position, 
                      LocalAccess.new(SimpleString.new 'ret_error'), 
                      SimpleString.new("return_value"),
                      Collections.emptyList,
                      nil 
                      ))
    else
      Node(ImplicitNil.new)
    end
    Rescue.new(block.position,
               [call],
               [
                RescueClause.new(
                  block.position,
                  [makeTypeName(block.position, nlr_klass)],
                  SimpleString.new('ret_error'),
                  [  Return.new(block.position, return_value)
                  ]
                )
              ],nil
                )
  end

  def void_type? type: ResolvedType
    @types.getVoidType.resolve.equals type
  end

  def void_type? type: TypeFuture
    @types.getVoidType.resolve.equals type.resolve
  end

  def convert_returns_to_raises block: Block, nlr_klass: ClosureDefinition, nlr_return_type: AssignableTypeFuture
    # block = Block(block.clone) # I'd like to do this, but it's ...
    return_nodes(block).each do |_n|
      node = Return(_n)

      type = if node.value
               infer(node.value)
             else
               @types.getVoidType
             end
      nlr_constructor_args = if void_type?(nlr_return_type) && (@types.getImplicitNilType.resolve == type.resolve)
                               Collections.emptyList
                             else
                               [node.value]
                             end
      nlr_return_type.assign type, node.position

      _raise = Raise.new(node.position, [
        Call.new(node.position,
          makeTypeName(node.position, nlr_klass),
          SimpleString.new('new'),
          nlr_constructor_args,
          nil)
        ])
      node.parent.replaceChild node, _raise
    end
    block
  end

  def contains_return block: Node
    !return_nodes(block).isEmpty
  end

  def return_nodes(block: Node): List
    #block.findDescendants { |c| c.kind_of? Return }
    # from findDescendants
    # from commented out code in the parser
    # TODO(nh): put this back in the parser
    finder = DescendentFinder.new(false, false) { |c| c.kind_of? Return }
    finder.scan(block, nil)
    finder.results
  end

# from commented out code in the parser
# TODO(nh): put this back in the parser
  class DescendentFinder < NodeScanner
    def initialize(children_only: boolean, only_one: boolean, filter: NodeFilter)
      @results = ArrayList.new
      @children = children_only
      @only_one = only_one
      @filter = filter
    end
 
    def enterDefault(node: Node, arg: Object): boolean
      return false if @results.size == 1 && @only_one
      if @filter.matchesNode(node)
       @results.add(node)
       return false if @only_one
      end
      return !@children
    end
 
    def results: List
      @results
    end
 
    def result: Node
      if @results.size == 0
        nil
      else
        Node(@results.get(0))
      end
    end
  end

  def new_closure_call_node(block: Block, klass: Node): Call
    closure_type = infer(klass)
    target = makeTypeName(block.position, closure_type.resolve)
    Call.new(block.position, target, SimpleString.new("new"), [BindingReference.new], nil)
  end

  # Builds an anonymous class.
  def build_class(position: Position, parent_type: ResolvedType, name:String=nil)
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
    constant = nil
    constant = Constant.new(position, SimpleString.new(position, name)) if name
    ClosureDefinition.new(position, constant, superclass, Collections.emptyList, interfaces, nil)
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

  # Builds MethodDefinitions in klass for the abstrace methods in iface.
  def build_method(klass: ClassDefinition, block: Block, iface: ResolvedType, parent_scope: Scope)
    methods = @types.getAbstractMethods(iface)
    if methods.size != 1
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
      method = MethodDefinition.new(block.position, name, args, return_type, nil, nil)
      method.body = NodeList(block.body.clone)

      set_parent_scope method, parent_scope

      klass.body.add(method)
    end
  end

  def build_constructor(enclosing_body: NodeList, klass: ClassDefinition, parent_scope: Scope): void
    parent_scope.binding_type ||= begin
                                    binding_klass = build_class(klass.position, nil)
                                    insert_into_body enclosing_body, binding_klass
                                    infer(binding_klass).resolve
                                  end
    binding_type_name = makeTypeName(klass.position, parent_scope.binding_type)
    args = Arguments.new(klass.position,
                         [RequiredArgument.new(SimpleString.new('binding'), binding_type_name)],
                         Collections.emptyList,
                         nil,
                         Collections.emptyList,
                         nil)
    body = FieldAssign.new(SimpleString.new('binding'), LocalAccess.new(SimpleString.new('binding')), nil)
    constructor = ConstructorDefinition.new(SimpleString.new('initialize'), args, SimpleString.new('void'), [body], nil)
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
