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
import org.mirah.util.Logger
import java.util.Collections
import java.util.Collection
import java.util.LinkedHashMap
import java.util.HashSet
import java.util.LinkedHashSet
import java.util.List
import java.util.Stack
import java.util.Map
import java.util.Map.Entry
import java.util.ArrayList
import java.io.File

import org.mirah.jvm.compiler.ProxyCleanup
import org.mirah.jvm.mirrors.MirrorScope
import org.mirah.jvm.mirrors.BaseType
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.jvm.mirrors.MirrorFuture
import org.mirah.macros.MacroBuilder
import org.mirah.typer.simple.TypePrinter2
import org.mirah.typer.CallFuture
import org.mirah.typer.BaseTypeFuture
import org.mirah.util.AstFormatter


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


# better idea:
#   add_todo doesn't add blocks + types.
#      it adds Script parents to set of them
#      finish iters over scripts to find block -> type map
#      then does them
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
    @scripts = LinkedHashSet.new
    @macros = macros
  end


# NLR
# in finish
# iter blocks
#  check for returns
#  next if !returns
#  gen up exception type
#  replace returns with raise of exception type
#  re-infer
#  enclosing = find Script or MethodDefinition
#  save (exceptiontype, enclosing) tuple
# iter enclosings
#  wrap w/ rescue of exceptiontype
#  re-infer


  # TODO better positions!!
  # the positions should be synthetic, or should be carefully pointed at the closest thing
  # maybe source locations could encode some info...
  class BindingAdjuster < NodeScanner
    def self.initialize
      @@log = Logger.getLogger(BindingAdjuster.class.getName)
    end

    def initialize(
       builder: BetterClosureBuilder,
       bindingName: String,
       parent_scope: MirrorScope,
       blockToBindings: Map,
       bindingLocalNamesToTypes: Map)

      @builder = builder
      @captured = parent_scope.capturedLocals

      @blockToBindings = blockToBindings
      @bindingLocalNamesToTypes = bindingLocalNamesToTypes

      @blocks = Stack.new
      @parent_scope = parent_scope
      @bindingName = bindingName
    end

    def adjust(node: Node): void
      @@log.fine "adjusting #{node}\n#{@builder.typer.sourceContent node}"
      @@log.fine "captures for #{@bindingName}: #{@parent_scope.capturedLocals} parent scope: #{@parent_scope}"

      if @captured.isEmpty
        @@log.fine "no need for binding adjustment here. Nothing captured"
        return
      end
      if @parent_scope.declared_binding_type
        @@log.fine "no need for binding adjustment here. already bound to #{@parent_scope.declared_binding_type}"
        return
      end

      # construct binding
      name = @builder.temp_name_from_outer_scope(node, "ZBinding")
      
      @@log.fine("building binding #{name} with captures #{@captured}")
      binding_klass = @builder.build_class(
        node.position, nil, name)

      entries = @captured.map do |cap: String|
        type = @parent_scope.getLocalType(cap, node.position).resolve
        HashEntry.new(SimpleString.new(cap), Constant.new(SimpleString.new(type.name)))
      end

      attr_def = FunctionalCall.new(
        SimpleString.new("attr_accessor"),
        [Hash.new(node.position, entries)],
        nil)
      binding_klass.body.insert(0, attr_def)
            
      binding_new_call = Call.new(node.position, Constant.new(SimpleString.new(name)), SimpleString.new("new"), [], nil)
      @builder.typer.workaroundASTBug binding_new_call

      assign_binding_dot_new = LocalAssignment.new(
          node.position,
          SimpleString.new(@bindingName),
          binding_new_call)
      
      @@log.fine "inserted binding assign / binding class "
      @builder.insert_into_body NodeList(node), assign_binding_dot_new
      @builder.insert_into_body NodeList(node), binding_klass
      
      binding_type = @builder.infer(binding_klass).resolve

      raise "parent_scope had declared_binding_type already #{@parent_scope}" if @parent_scope.declared_binding_type
      @parent_scope.declared_binding_type = binding_type
      @bindingLocalNamesToTypes[@bindingName] = binding_type
      
      @binding_type = @builder.infer(binding_klass)
      @binding_klass_node = binding_klass
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
      if arguments
        arguments.required.each {|a: FormalArgument| arg_names.add a.name.identifier } if arguments.required
        arguments.optional.each {|a: FormalArgument| arg_names.add a.name.identifier } if arguments.optional
        arg_names.add arguments.rest.name.identifier if arguments.rest
        arguments.required2.each {|a: FormalArgument| arg_names.add a.name.identifier } if arguments.required2
        arg_names.add arguments.block.name.identifier if arguments.block
      else
        if mdef || block_parent
          @@log.fine "parent had no arguments: parent #{mdef} #{block_parent}"
        else
          @@log.fine "had no parent"
        end
      end
      @@log.fine "adding assignments from args to captures"
      arg_names.each do |arg|
        if @captured.contains arg
          addition = Call.new(
            blockAccessNode(node.position),
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

    def enterClosureDefinition(node, blah)
      # skip the definition of the binding we're in the process of inserting
      @binding_klass_node != node
    end


    def exitClosureDefinition(node, blah)
      # might be a lambda created by the lambda macro
      # if contained captures?
      #  ; containing captures here implies a closure not built via this, because this builds them inside out
      #    adjust initializer to add binding
      #    add method for referring to binding by name
      #    find new call, and adjust it to include the binding just added to the initializer
    end

    def enterBlock(node, blah)
      @blocks.push node
      @blockToBindings[@blocks.peek] ||= HashSet.new

      true
    end

    def exitBlock(node, blah)
      @blocks.pop
    end

    def maybeNoteBlockBinding
      @blocks.each do |block: Block|
        Collection(@blockToBindings[block]).add @bindingName
      end
    end

    def blockAccessNode(position: Position)
      name_node = SimpleString.new(@bindingName)
      if @blocks.isEmpty
        LocalAccess.new(position, name_node)
      else
        FieldAccess.new(position, name_node)
      end
    end

    def exitLocalAssignment(local, blah)
      local_name = local.name.identifier
      return nil unless @captured.contains local_name

      @@log.finest "enterLocalAssignment: replacing #{local.name.identifier} with #{@bindingName}.#{local.name.identifier}="
      @@log.finest "  Type: #{@builder.typer.getInferredType(local)}"

      maybeNoteBlockBinding

      new_value = Node(local.value)
      new_value.setParent(nil)
      replacement = Call.new(
        blockAccessNode(local.position),
        SimpleString.new("#{local.name.identifier}_set"),
        [new_value],
        nil)

      @builder.typer.workaroundASTBug replacement

      replaceSelf(local, replacement)
      local.value.setParent replacement

      @builder.typer.learnType replacement.target, @binding_type
      @builder.typer.infer new_value
      @builder.typer.infer replacement
    end

    def exitLocalAccess(local, blah)
      local_name = local.name.identifier
      return nil unless @captured.contains local_name

      @@log.finest "enterLocalAccess: replacing #{local.name.identifier} with #{@bindingName}.#{local.name.identifier}="
      @@log.finest "  Type: #{@builder.typer.getInferredType(local)}"
      
      maybeNoteBlockBinding

      replacement = Call.new(
        blockAccessNode(local.position),
        SimpleString.new(local.position,local.name.identifier),
        [],
        nil)

      @builder.typer.workaroundASTBug replacement

      replaceSelf(local, replacement)

      @builder.typer.learnType replacement.target, @binding_type

      @@log.fine "does replacement have parent?: #{replacement.parent}"
      @@log.fine "does replacement parent 0th child: #{NodeList(replacement.parent).get(0)}" if replacement.parent.kind_of? NodeList
      @@log.fine "does replacement have parent?: #{replacement.parent.parent}" if replacement.parent
      @builder.typer.infer replacement
    end

    def replaceSelf me: Node, replacement: Node
      me.parent.replaceChild(me, replacement)
    end
  end

  class BlockFinder < NodeScanner
    def initialize(typer: Typer, todo_closures: Map)
      @typer = typer
      @todo_closures = todo_closures
    end
    def find(node: Script): Map
      collection = LinkedHashMap.new
      node.accept(self, collection)
      collection
    end

    def enterMacroDefinition(node, notes)
      false
    end

    def exitBlock(node, notes)
      type = if @todo_closures[node]
        @todo_closures[node]
      else
        #t = @typer.getInferredType(node).resolve
        #if t.kind_of? MethodType
          parent_type_future = @typer.getInferredType(node.parent)
          unless parent_type_future
            puts "#{CallSite(node.parent).name} call with block has no type at #{node.parent.position}"
            puts "  block type: #{@typer.getInferredType(node)}"
          end
          fs = CallFuture(parent_type_future).futures
          TypeFuture(fs.get(fs.size-1)).resolve
        #else
        #end
      end
      Map(notes).put node, type
    end
  end


  def finish
    closures = []
    scripts = ArrayList.new(@scripts)
    Collections.reverse(scripts)
    scripts.each do |s: Script|
      closures.addAll BlockFinder.new(@typer, @todo_closures).find(s).entrySet
    end

    closures_to_skip = []

    blockToBindings = LinkedHashMap.new # the list of bindings a block closes over
    bindingLocalNamesToTypes = LinkedHashMap.new

    bindingForBlocks = LinkedHashMap.new # the specific binding for a given block
    i = 0
    closures.each do |entry: Entry|
      @@log.fine "adjust bindings for block #{entry.getKey} #{entry.getValue} #{i}"
      i += 1
      block = Block(entry.getKey)
      @@log.fine "#{typer.sourceContent block}"
      enclosing_node = find_enclosing_node(block)
      if enclosing_node.nil?
        # this likely means a macro exists and made things confusing 
        # by copying the tree
        @@log.fine "enclosing node was nil, removing  #{entry.getKey} #{entry.getValue} #{i}"
        closures_to_skip.add entry
        next
      end
      @@log.fine "enclosing node #{enclosing_node}"
      @@log.fine "#{typer.sourceContent enclosing_node}"

      ProxyCleanup.new.scan enclosing_node

      enclosing_b = get_body(enclosing_node)      
      if enclosing_b.nil?
        closures_to_skip.add entry
        next
      end
      bindingName = "b#{i}"
      bindingForBlocks.put block, bindingName
      adjuster = BindingAdjuster.new(
        self,
        bindingName,
        MirrorScope(get_scope(block)),
        blockToBindings,
        bindingLocalNamesToTypes)

      adjuster.adjust enclosing_b
    end

    # ignore closures with no parents, they aren't in the final AST, maybe
    closures.removeAll closures_to_skip

    i = 0
    closures.each do |entry: Entry|
      @@log.fine "insert_closure #{entry.getKey} #{entry.getValue} #{i}"
      i += 1

      block = Block(entry.getKey)
      parent_type = ResolvedType(entry.getValue)

      unless get_body(find_enclosing_node(block))
        @@log.fine "  enclosing node was nil, removing  #{entry.getKey} #{entry.getValue} #{i}"
        next
      end

      closure_name = temp_name_from_outer_scope(block, "Closure")
      closure_klass = build_class(block.position, parent_type, closure_name)

      # build closure class
      binding_list = Collection(blockToBindings.get(block)) || Collections.emptyList
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
        SimpleString.new('initialize'), args,
        SimpleString.new('void'), binding_assigns, nil)
      closure_klass.body.add(constructor)

      enclosing_b  = find_enclosing_body block
      if binding_assigns.isEmpty
        insert_into_body enclosing_b, closure_klass
      else 
        # insert after binding class, for happier typing
        # also causes weird issues in the compiler if things are out of order
        enclosing_b.insert(1, closure_klass)
      end

      block_scope = get_scope block
      if contains_methods(block)
        copy_methods(closure_klass, block, block_scope)
      else
        build_and_inject_methods(closure_klass, block, parent_type, block_scope)
      end

      closure_type = infer(closure_klass)

      has_block_parent = block.findAncestor { |node| node.parent.kind_of? Block }

      binding_locals = binding_list.map do |name: String|
        # the current block's binding won't be a field
        if has_block_parent && !name.equals(bindingForBlocks.get(block))
          FieldAccess.new(SimpleString.new(name))
        else
          LocalAccess.new(SimpleString.new(name))
        end
      end
      target = makeTypeName(block.position, closure_type.resolve)
      new_node = Call.new(
        block.position, target,
        SimpleString.new("new"), 
        binding_locals, nil)
      @typer.workaroundASTBug new_node

      

      if block.parent.kind_of?(CallSite)
        parent = CallSite(block.parent)
        replace_block_with_closure_in_call parent, block, new_node
      else
        replace_synthetic_lambda_definiton_with_closure(SyntheticLambdaDefinition(block.parent),new_node)
      end

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
    return if parent_type.isError || block.parent.nil?
    
    rtype = BaseTypeFuture.new(block.position)
    rtype.resolved parent_type
  
    new_scope = @typer.addNestedScope block
    new_scope.selfType = rtype
    if contains_methods block
      @typer.infer block.body
    else
      @typer.inferClosureBlock block, method_for(parent_type)
    end

    script = block.findAncestor{|n| n.kind_of? Script}

    @todo_closures[block] = parent_type
    @scripts.add script
  end

  def insert_closure(block: Block, parent_type: ResolvedType)
    raise "BetterClosureBuilder doesn't support insert_closure"
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
      build_and_inject_methods(klass, block, parent_type, parent_scope)
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
  
  def replace_synthetic_lambda_definiton_with_closure(parent: SyntheticLambdaDefinition, new_node: Node): void
    parentparent = parent.parent
    new_node.setParent(nil)
    if parentparent.kind_of?(CallSite) # then the SyntheticLambdaDefinition is not a child of the CallSite itself, but (most likely?) a child of its arguments. FIXME: It is weird that the parent of a child of X is not X. 
      CallSite(parentparent).parameters.replaceChild(parent,new_node)
    else
      parentparent.replaceChild(parent,new_node)
    end
  end

  def find_enclosing_body block: Block
    enclosing_node = find_enclosing_node block
    get_body enclosing_node
  end

  def get_body node: Node
    # TODO create an interface for nodes with bodies
    if node.kind_of?(MethodDefinition)
      MethodDefinition(node).body
    elsif node.kind_of?(Script)
      Script(node).body
    elsif node.kind_of?(Block)
      Block(node).body
    else
      raise "Unknown type for finding a body #{node.getClass}"
    end
  end

  def find_enclosing_node block: Node
    if block.parent
      # findAncestor includes the start node, so we start with the parent
      block.parent.findAncestor do |node|
        node.kind_of?(MethodDefinition) ||
        node.kind_of?(Script) ||
        node.kind_of?(Block)
      end
    end
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
                   MirrorTypeSystem.getMainClassName(Script(class_or_script))
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
    
    build_and_inject_methods(klass, block, parent_type, parent_scope)
  
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

  def makeSimpleTypeName(position: Position, type: ResolvedType)
    SimpleString.new(position, type.name)
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
    return MethodType(iface) if iface.kind_of? MethodType

    methods = @types.getAbstractMethods(iface)
    if methods.size == 0
      @@log.warning("No abstract methods in #{iface}")
      raise UnsupportedOperationException, "No abstract methods in #{iface}"
    elsif methods.size > 1
      raise UnsupportedOperationException, "Multiple abstract methods in #{iface}: #{methods}"
    end
    MethodType(List(methods).get(0))
  end

  # builds the method definitios for inserting into the closure class
  def build_methods_for(mtype: MethodType, block: Block, parent_scope: Scope): List #<MethodDefinition>
    methods = []
    name = SimpleString.new(block.position, mtype.name)

    # TODO handle all arg types allowed
    args = if block.arguments
             Arguments(block.arguments.clone)
           else
             Arguments.new(block.position, Collections.emptyList, Collections.emptyList, nil, Collections.emptyList, nil)
           end

    while args.required.size < mtype.parameterTypes.size
      arg = RequiredArgument.new(
        block.position, SimpleString.new("arg#{args.required.size}"), nil)
      args.required.add(arg)
    end
    return_type = makeSimpleTypeName(block.position, mtype.returnType)
    block_method = MethodDefinition.new(block.position, name, args, return_type, nil, nil)

    block_method.body = NodeList(block.body.clone)

    m_types= mtype.parameterTypes


    # Add check casts in if the argument has a type
    i=0
    args.required.each do |a: RequiredArgument|
      if a.type
        m_type = BaseType(m_types[i])
        a_type = @types.get(parent_scope, a.type.typeref).resolve
        if !a_type.equals(m_type) # && BaseType(m_type).assignableFrom(a_type) # could do this, then it'd only add the checkcast if it will fail...
          block_method.body.insert(0, 
            Cast.new(a.position, 
              Constant.new(SimpleString.new(m_type.name)), LocalAccess.new(a.position, a.name))
            )
        end
      end
      i+=1
    end

    methods.add(block_method)

    # create a bridge method if necessary
    requires_bridge = false
    # What I'd like it to look like:
    # args.required.zip(m_types).each do |a, m|
    #   next unless a.type
    #   a_type = @types.get(parent_scope, a.type.typeref)
    #   if a_type != m
    #     requires_bridge = true
    #     break
    #   end
    # end
    i=0
    args.required.each do |a: RequiredArgument|
      if a.type
        m_type = BaseType(m_types[i])
        a_type = @types.get(parent_scope, a.type.typeref).resolve
        if !a_type.equals(m_type) # && BaseType(m_type).assignableFrom(a_type)
          @@log.fine("#{name} requires bridge method because declared type: #{a_type} != iface type: #{m_type}")
          requires_bridge = true
          break
        end
      end
      i+=1
    end

    if requires_bridge
      # Copy args without type information so that the normal iface lookup will happen
      # for the args with types args, add a cast to the arg for the call
      bridge_args = Arguments.new(args.position, [], Collections.emptyList, nil, Collections.emptyList, nil)
      call = FunctionalCall.new(name, [], nil)
      args.required.each do |a: RequiredArgument|
        bridge_args.required.add(RequiredArgument.new(a.position, a.name, nil))
        local = LocalAccess.new(a.position, a.name)
        param = if a.type
                  Cast.new(a.position, a.type, local)
                else
                  local
                end
        call.parameters.add param
      end
        
      bridge_method = MethodDefinition.new(args.position, name, bridge_args, return_type, nil, nil)
      bridge_method.body = NodeList.new(args.position, [call])
      anno = Annotation.new(args.position, Constant.new(SimpleString.new('org.mirah.jvm.types.Modifiers')),
                         [HashEntry.new(SimpleString.new('flags'), Array.new([SimpleString.new('BRIDGE')]))])
      bridge_method.annotations.add(anno)
      methods.add(bridge_method)
    end
    methods
  end

  # Builds MethodDefinitions in klass for the abstract methods in iface.
  def build_and_inject_methods(klass: ClassDefinition, block: Block, iface: ResolvedType, parent_scope: Scope):void
    mtype = method_for(iface)

    methods = build_methods_for mtype, block, parent_scope
    methods.each do |m: Node|
      klass.body.add m
    end
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
