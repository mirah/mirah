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
import java.util.logging.Level
import java.util.logging.Logger
import java.util.Collections
import java.util.Collection
import java.util.LinkedHashMap
import java.util.HashSet
import java.util.List
import java.util.Stack
import java.util.Map
import java.util.Map.Entry
import java.util.ArrayList
import java.io.File


import org.mirah.jvm.compiler.ProxyCleanup


import org.mirah.jvm.mirrors.MirrorScope
import org.mirah.macros.MacroBuilder

import org.mirah.typer.simple.TypePrinter2
import org.mirah.typer.CallFuture
import org.mirah.util.AstFormatter
# This class transforms a Block into an anonymous class once the Typer has figured out
# the interface to implement (or the abstract superclass).
#
# Note: This is ugly. It depends on the internals of the JVM scope and jvm_bytecode classes,
# and the BindingReference node is a hack. This should really all be cleaned up.
class BetterClosureBuilder
  implements ClosureBuilderer

  attr_reader typer: Typer

  def self.initialize: void
    @@log = Logger.getLogger(BetterClosureBuilder.class.getName)
  end

  def initialize(typer: Typer, macros: MacroBuilder)
    @typer = typer
    @types = typer.type_system
    @scoper = typer.scoper
    @todo_closures = LinkedHashMap.new
    @macros = macros
  end
# TODO better positions!!
# the positions should be synthetic, or should be carefully pointed at the closest thing
# maybe source locations could encode some info...
class BindingAdjuster < NodeScanner
  def self.initialize
    @@log = Logger.getLogger(BindingAdjuster.class.getName)
  end
  def initialize(
     builder:BetterClosureBuilder,
     bindingName:String,
     captured: List, 
     parent_scope: MirrorScope,
     blockToBindings: Map,
     bindingLocalNamesToTypes: Map)

    @builder = builder
    @captured = captured

    @blockToBindings = blockToBindings
    @bindingLocalNamesToTypes = bindingLocalNamesToTypes
    
    @blocks = Stack.new
    @parent_scope = parent_scope
    @bindingName = bindingName

    @@log.fine "instantiated adjuster"
  end

  def adjust(node: Node): void
    ProxyCleanup.new.scan node

    @@log.fine "adjusting #{node}"
    @@log.fine "captures for #{@bindingName}: #{@parent_scope.capturedLocals}"

    if @captured.isEmpty
      @@log.fine "no need for binding adjustment here. Nothing captured"
      return
    end
    if @parent_scope.declared_binding_type
      @@log.fine "no need for binding adjustment here. already bound to #{@parent_scope.declared_binding_type}"
      return
    end

    name = @builder.temp_name_from_outer_scope(node, "Binding")
    
    @@log.fine("building binding #{name} with captures #{@captured}")
    binding_klass = @builder.build_class(
      node.position,
      nil,
      name)

    entries = @captured.map do |cap: String|
      type = @parent_scope.getLocalType(cap, node.position).resolve
      HashEntry.new(SimpleString.new(cap), Constant.new(SimpleString.new(type.name)))
    end

    attr_def = FunctionalCall.new(
      SimpleString.new("attr_accessor"),
      [Hash.new(node.position, entries)],
      nil)
    binding_klass.body.insert(0, attr_def)

    binding_type = @builder.infer(binding_klass).resolve
    @parent_scope.declared_binding_type = binding_type
    @bindingLocalNamesToTypes[@bindingName] = binding_type

    binding_new_call = Call.new(node.position, Constant.new(SimpleString.new(name)), SimpleString.new("new"), [], nil)
    @builder.typer.workaroundASTBug binding_new_call

    assign_binding_dot_new = LocalAssignment.new(
        node.position,
        SimpleString.new(@bindingName),
        binding_new_call
      )
    
    @builder.insert_into_body NodeList(node), assign_binding_dot_new
    @builder.insert_into_body NodeList(node), binding_klass
    @@log.fine "inserted binding class"

    @binding_type = @builder.infer(binding_klass)
    @builder.infer assign_binding_dot_new
    @@log.fine "binding assignment inference done"

    @@log.fine "replacing references to captures"

    mdef = node.findAncestor{ |n| n.kind_of? MethodDefinition }
    block_parent = node.findAncestor { |n| n.kind_of? Block }

    arguments = if mdef
      MethodDefinition(mdef).arguments
    elsif block_parent
      Block(block_parent).arguments
    end

    

    node.accept self, 1
    @@log.fine "finished phase one of capture replacement"


    arg_names = []
    arguments.required.each {|a: FormalArgument| arg_names.add a.name.identifier } if arguments.required
    arguments.optional.each {|a: FormalArgument| arg_names.add a.name.identifier } if arguments.optional
    arg_names.add arguments.rest.name.identifier if arguments.rest
    arguments.required2.each {|a: FormalArgument| arg_names.add a.name.identifier } if arguments.required2
    arg_names.add arguments.block.name.identifier if arguments.block


    @@log.fine "adding assignments from args to captures"
    arg_names.each do |arg|
      if @captured.contains arg
        addition = Call.new(
          blockAccessNode(node),
          #SimpleString.new("#{local.name.identifier}="),
          SimpleString.new("#{arg}_set"),
          [LocalAccess.new(node.position, SimpleString.new(arg))],
          nil)
        @builder.typer.workaroundASTBug addition
         # insert after binding class & binding instantiation
         # if we were less lazy, we'd find the binding construction, and insert after
        NodeList(node).insert 2, addition

        @builder.infer addition
      end
    end

    @@log.fine "done replacing references"

  end

  def enterBlock(node, blah)
    @blocks.push node
    @blockToBindings[@blocks.peek] ||= HashSet.new
    
    true
  end

  def exitBlock(node, blah)
    @blocks.pop
  end

# need to note args as well, because we need to copy them to the binding
# enter arguments
# exit arguments

  def maybeNoteBlockBinding
    @blocks.each do |block: Block|
      Collection(@blockToBindings[block]).add @bindingName
    end
  end

  def blockAccessNode(local: Node)
    new_node = if @blocks.isEmpty
        LocalAccess.new(
          local.position,
          SimpleString.new(@bindingName))
      else
        FieldAccess.new(
          local.position,
          SimpleString.new(@bindingName))
      end
    new_node
  end

  def exitLocalAssignment(local, blah)
    @@log.fine "visitLocalAssignment #{local} #{@builder.typer.getInferredType(local)}"
    local_name = local.name.identifier
    if @captured.contains local_name
      @@log.fine "visitLocalAssignment: replacing #{local.name.identifier} with #{@bindingName}.#{local.name.identifier}="
      maybeNoteBlockBinding
      
      #local.value.setParent(nil)
      new_value = Node(local.value)#.clone)
      new_value.setParent(nil)
      replacement = Call.new(
        blockAccessNode(local),
        #SimpleString.new("#{local.name.identifier}="),
        SimpleString.new("#{local.name.identifier}_set"),
        [new_value],
        nil)

      @builder.typer.workaroundASTBug replacement
      
      replaceSelf(local, replacement)

      @builder.typer.learnType replacement.target, @binding_type
@@log.fine "---------------------------------------------------------"
@@log.fine "visitLocalAssignment infer value "
@@log.fine "---------------------------------------------------------"
      local.value.setParent replacement
      @builder.typer.infer new_value
@@log.fine "---------------------------------------------------------"
@@log.fine "END visitLocalAssignment infer value "
@@log.fine "---------------------------------------------------------"

      @builder.typer.infer replacement

@@log.fine "---------------------------------------------------------"
@@log.fine "END visitLocalAssignment infer replacement in total "
@@log.fine "---------------------------------------------------------"

    end
    nil
  end

  def exitLocalAccess(local, blah)
    @@log.fine "visitLocalAccess #{local}  #{@builder.typer.getInferredType(local)}"
    local_name = local.name.identifier
    if @captured.contains local_name
      @@log.fine "visitLocalAccess: replacing #{local.name.identifier} with #{@bindingName}.#{local.name.identifier}"
      maybeNoteBlockBinding

      replacement = Call.new(
        blockAccessNode(local),
        SimpleString.new(local.position,local.name.identifier),
        [],
        nil)

      @builder.typer.workaroundASTBug replacement
            # TODO create a callfuture
      
      replaceSelf(local, replacement)
      
      @builder.typer.learnType replacement.target, @binding_type
      
      @@log.fine "does replacement have parent?: #{replacement.parent}"
      @@log.fine "does replacement parent 0th child: #{NodeList(replacement.parent).get(0)}" if replacement.parent.kind_of? NodeList
      @@log.fine "does replacement have parent?: #{replacement.parent.parent}" if replacement.parent
  #    @builder.typer.learnType(replacement, @builder.typer.infer(local))
      @builder.typer.infer replacement
    end
    
    nil  
  end

 # def enterStringConcat(node, blah)
  #  @@log.fine "enter #{node}"
  #  true
  #end

#  def enterNodeList(node, blah)
#    @@log.fine "enterNodeList #{node} #{node.size}"
#    true
#  end
#def enterOther(node, blah)
#  @@log.fine "enterOther #{node}"
#    true
#end
  def replaceSelf me: Node, replacement: Node
    # argh, proxy nodes!
    #if me.parent.kind_of? ProxyNode
    #  me.parent.parent.replaceChild(me.parent, replacement)
    #else
      me.parent.replaceChild(me, replacement)
    #end
  end
end

  def finish
    # reverse closures s.t. we do nested closures 
    # before doing the ones they nest inside
    # TODO add extension for this Collection#reverse
    closures = ArrayList.new(@todo_closures.entrySet)
    Collections.reverse(closures)


    blockToBindings=LinkedHashMap.new
    bindingLocalNamesToTypes=LinkedHashMap.new
    i = 0
    closures.each do |entry: Entry|
      @@log.fine "insert_closure #{entry.getKey} #{entry.getValue} #{i}"
      i+=1
      block = Block(entry.getKey)
      enclosing_b = get_body(
        find_enclosing_node(block)
        )
      enclosing_scope = get_scope(enclosing_b)
      adjuster = BindingAdjuster.new(
        self,
       "b#{i}",
        get_scope(block).capturedLocals,
        MirrorScope(get_scope(block)),
        blockToBindings,
        bindingLocalNamesToTypes)

      adjuster.adjust enclosing_b
    end

    i = 0
    closures.each do |entry: Entry|
      @@log.fine "insert_closure #{entry.getKey} #{entry.getValue} #{i}"
      i+=1

      block = Block(entry.getKey)
      parent_type = ResolvedType(entry.getValue)
      binding_list = Collection(blockToBindings.get(block)) || Collections.emptyList

      closure_name = temp_name_from_outer_scope(block, "Closure")

      closure_klass = build_class(block.position, parent_type, closure_name)


      enclosing_b  = find_enclosing_body block

      block_scope = get_scope block.body
      @@log.fine "block body scope #{block_scope.getClass} #{MirrorScope(block_scope).capturedLocals}"


      block_scope = get_scope block
      @@log.fine "block scope #{block_scope} #{MirrorScope(block_scope).capturedLocals}"
      #@@log.fine "parent scope #{parent_scope} #{MirrorScope(parent_scope).capturedLocals}"
      enclosing_scope = get_scope(enclosing_b)
      @@log.fine "enclosing scope #{enclosing_scope} #{MirrorScope(enclosing_scope).capturedLocals}"

# build closure class
      binding_args = binding_list.map do |name: String|
        RequiredArgument.new(SimpleString.new(name), SimpleString.new(ResolvedType(bindingLocalNamesToTypes[name]).name))
      end

      args = Arguments.new(closure_klass.position,
                           binding_args,
                           Collections.emptyList,
                           nil,
                           Collections.emptyList,
                           nil)
      binding_assigns = binding_list.map do |name: String|
        FieldAssign.new(SimpleString.new(name), LocalAccess.new(SimpleString.new(name)), nil)
      end
      constructor = ConstructorDefinition.new(
        SimpleString.new('initialize'),
        args,
        SimpleString.new('void'),
        binding_assigns,
        nil)
      closure_klass.body.add(constructor)

      # insert after binding class, for happier typing
      enclosing_b.insert(1, closure_klass)
      #insert_into_body enclosing_b, closure_klass

      if contains_methods(block)
        copy_methods(closure_klass, block, block_scope)
      else
        build_method(closure_klass, block, parent_type,block_scope)
      end


    closure_type = infer(closure_klass)


      has_block_parent = block.findAncestor { |node| node.parent.kind_of? Block }

      binding_locals = binding_list.map do |name: String|
        if has_block_parent
          FieldAccess.new(SimpleString.new(name))
        else
          LocalAccess.new(SimpleString.new(name))
        end
      end
    target = makeTypeName(block.position, closure_type.resolve)
    new_node = Call.new(
      block.position,
      target,
      SimpleString.new("new"), 
      binding_locals,
      nil)
      @typer.workaroundASTBug new_node
      parent = CallSite(block.parent)
      replace_block_with_closure_in_call parent, block, new_node
      
      infer new_node
      infer enclosing_b



    @@log.fine "done with #{enclosing_b}"
    @@log.log(Level.FINE, "Inferred types:\n{0}", AstFormatter.new(enclosing_b))

            buf = java::io::ByteArrayOutputStream.new
        ps = java::io::PrintStream.new(buf)
        printer = TypePrinter2.new(@typer, ps)
        printer.scan(enclosing_b, nil)
        ps.close()
      @@log.fine("Inferred types for expr:\n#{String.new(buf.toByteArray)}")


    end
  end



  def add_todo(block: Block, parent_type: ResolvedType)

# need to infer block contents so that capture list in scopes is right
# could do this another way tho
#
#   -  create closure structures
#   -  reassign scopes to closure scopes in original tree
#   -  type all the things
#   -  add bindings
# since we're going backwards, it might just work!
    new_scope = @typer.addNestedScope block



    rtype = BaseTypeFuture.new(block.position)
    rtype.resolved parent_type
  
    new_scope.selfType = rtype
    if contains_methods block
      @typer.infer block.body
    else
      method_type = method_for(parent_type)
      @typer.logger.fine "block is closure with scope #{new_scope}"
      @typer.inferClosureBlock block, method_type
    end
    @todo_closures[block]=parent_type
  end

  def insert_closure(block: Block, parent_type: ResolvedType)
    # TODO: This will fail if the block's class changes.
    #new_node =  if has_non_local_return block
    #              prepare_non_local_return_closure(block, parent_type)
    #            else
    new_node =               prepare_regular_closure(block, parent_type)
    #            end

    parent = CallSite(block.parent)
    replace_block_with_closure_in_call parent, block, new_node
    infer(new_node)
  end

  def prepare(block: Block, parent_type: ResolvedType): Call
    Call(prepare_regular_closure(block, parent_type))
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
    build_class block.position,
                @types.getBaseExceptionType.resolve,
                temp_name_from_outer_scope(block, "NLRException")
  end

  def temp_name_from_outer_scope block: Node,  scoped_name: String
    class_or_script = block.findAncestor {|node| node.kind_of?(ClassDefinition) || node.kind_of?(Script)}
    outer_name = if class_or_script.kind_of? ClassDefinition
                   ClassDefinition(class_or_script).name.identifier
                 else
                  @@log.fine "#{class_or_script} is not a class"
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

    klass = build_class(block.position, parent_type, temp_name_from_outer_scope(block, "Closure"))
    
    enclosing_body  = find_enclosing_body block

block_scope = get_scope block.body
@@log.fine "block body scope #{block_scope.getClass} #{MirrorScope(block_scope).capturedLocals}"


block_scope = get_scope block
@@log.fine "block scope #{block_scope} #{MirrorScope(block_scope).capturedLocals}"
@@log.fine "parent scope #{parent_scope} #{MirrorScope(parent_scope).capturedLocals}"
enclosing_scope = get_scope(enclosing_body)
@@log.fine "enclosing scope #{enclosing_scope} #{MirrorScope(enclosing_scope).capturedLocals}"
    parent_scope.binding_type ||= begin
                                    name = temp_name_from_outer_scope(block, "Binding")
                                    captures = MirrorScope(parent_scope).capturedLocals
                                    @@log.fine("building binding #{name} with captures #{captures}")
                                    binding_klass = build_class(klass.position,
                                                                nil,
                                                                name)
                                    insert_into_body enclosing_body, binding_klass

              # add methods for captures
              # typer doesn't understand unquoted return types yet, perhaps
              # TODO write visitor to replace locals w/ calls to bound locals
             # captures.each do |bound_var: String|
             #   bound_type = MirrorScope(parent_scope).getLocalType(bound_var, block.position).resolve
             #   attr_def = @macros.quote do
             #     attr_accessor `bound_var` => `Constant.new(SimpleString.new(bound_type.name))`
             #   end
             #   binding_klass.body.insert(0, attr_def)
             # end

                                    infer(binding_klass).resolve
                                  end
    binding_type_name = makeTypeName(klass.position, parent_scope.binding_type)

    build_constructor(klass, binding_type_name)


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
    finder = DescendentFinder2.new(false, false) { |c| c.kind_of? Return }
    finder.scan(block, nil)
    finder.results
  end

# from commented out code in the parser
# TODO(nh): put this back in the parser
  class DescendentFinder2 < NodeScanner
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

  def method_for(iface: ResolvedType): MethodType
    methods = @types.getAbstractMethods(iface)
    if methods.size == 0
      @@log.warning("No abstract methods in #{iface}")
      raise UnsupportedOperationException, "No abstract methods in #{iface}"
    elsif methods.size > 1
      raise UnsupportedOperationException, "Multiple abstract methods in #{iface}: #{methods}"
    end
    MethodType(List(methods).get(0))
  end

  # Builds MethodDefinitions in klass for the abstract methods in iface.
  def build_method(klass: ClassDefinition, block: Block, iface: ResolvedType, parent_scope: Scope):void
    mtype = method_for(iface)
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

    # at this point it's safe to modify them I think, because the typer's done
    #method.body = NodeList(block.body.clone)
    # arg set does a clone if parent is set!!
    block.body.setParent nil
    method.body = NodeList(block.body)

# stop mucking w/ scope for now
   # set_parent_scope method, parent_scope

    klass.body.add(method)
  end

  def build_constructor(klass: ClassDefinition, binding_type_name: Constant): void
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

  def insert_into_body enclosing_body: NodeList, node: Node
    enclosing_body.insert(0, node)
  end

  def infer node: Node
    @typer.infer node
  end

  def set_parent_scope method: MethodDefinition, parent_scope: Scope
    @scoper.addScope(method).parent = parent_scope
  end
end
