# Copyright (c) 2012-2015 The Mirah project authors. All Rights Reserved.
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

package org.mirah.typer.closures

import mirah.lang.ast.*

import org.mirah.typer.Typer
import org.mirah.typer.BetterClosureBuilder
import org.mirah.jvm.types.JVMTypeUtils
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.mirrors.MirrorScope
import org.mirah.util.Logger

import java.util.Map
import java.util.LinkedHashMap
import java.util.Collection
import java.util.HashSet
import java.util.Stack
import java.util.logging.Level


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

    @blockToBindings = blockToBindings
    @bindingLocalNamesToTypes = bindingLocalNamesToTypes

    @blocks = Stack.new
    @parent_scope = parent_scope
    @bindingName = bindingName
  end

  def adjust(node: Node, block: Block):void
    @captured = @parent_scope.capturedLocals
    @@log.fine "adjusting #{node}\n#{@builder.typer.sourceContent node}\nfor block\n#{@builder.typer.sourceContent block}"
    @@log.fine "captures for #{@bindingName}: #{@captured} parent scope: #{@parent_scope}"

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
      type               = @parent_scope.getLocalType(cap, node.position).resolve
      if type.kind_of?(org::mirah::jvm::mirrors::NullType)
      # FIXME: This should use an "assert" facility which costs no runtime
      # in case the assertions are disabled
        raise "We have no type for captured variable \"#{cap}\"."
      end
      is_array           = JVMTypeUtils.isArray(JVMType(type))
      variable_type_name = type.name
      variable_type_name = variable_type_name.substring(0,variable_type_name.length-2) if is_array # chop off trailing "[]"
      variable_type_ref  = TypeRefImpl.new(variable_type_name, is_array, false, node.position)
      HashEntry.new(SimpleString.new(cap), variable_type_ref) # FIXME: there should be a method type.to_type_ref
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
    @builder.parent_scope_to_binding_name[@parent_scope] = @bindingName

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

  def visitClassDefinition(node, blah)
    nil # do not descent into classes which just happen to be defined in the scope which gets a closure
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
    @blockToBindings[@builder.blockCloneMapNewOld[@blocks.peek]] ||= HashSet.new

    true
  end

  def exitBlock(node, blah)
    @blocks.pop
  end

  def maybeNoteBlockBinding
    @blocks.each do |block: Block|
      Collection(@blockToBindings[@builder.blockCloneMapNewOld[block]]).add @bindingName
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