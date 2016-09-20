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
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.util.Logger

import java.util.Map
import java.util.LinkedHashMap
import java.util.Collection
import java.util.Collections
import java.util.HashSet
import java.util.Stack
import java.util.logging.Level




# BindingAdjuster
#
# Constructs the binding class for each closure.
# If a closure doesn't need a binding--ie there's no captures--it is not constructed.
#
#
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

  def adjust(node: Node, block: Block): void
    @captured = @parent_scope.capturedLocals

    # TODO it'd be better if the scope knew that binding vars were not capturable.
    @captured_fields = []
    @parent_scope.capturedFields.each {|f: String| @captured_fields.add f unless is_binding_field(f)}
    #@captured_fields = @parent_scope.capturedFields
    @captured_self = @parent_scope.capturedSelf


    @@log.fine "adjusting #{node}\n#{@builder.typer.sourceContent node}\nfor block\n#{@builder.typer.sourceContent block}"
    @@log.fine "parent scope: #{@parent_scope}"
    @@log.fine "captures for #{@bindingName}:"
    @@log.fine "  locals: #{@captured}"
    @@log.fine "  fields: #{@captured_fields}"
    @@log.fine "  self:   #{@captured_self}"

    # to handle fields, I essentially need to
    #  1. get or add bridges to classes whose fields have been captured
    #  2. find usages of fields / self / methods and replace them with calls to the bridges
    # BindingAdjuster's scan is responsible for 2.
    # I think we could have the binding adjuster responsible for that too
    # But doesn't have to be

    if @captured.isEmpty && @captured_fields.isEmpty && !@captured_self
      @@log.fine "no need for binding adjustment here. Nothing captured"
      return
    end
    if @parent_scope.declared_binding_type
      @@log.fine "no need for binding adjustment here. already bound to #{@parent_scope.declared_binding_type}"
      return
    end


    # If there are captured fields, we need to add method definitions to the 
    # class of the parent scope before introducing them into the closure bodies.
    if !@captured_fields.isEmpty
      # TODO these need to be marked synthetic
      # find class parent
      enclosing_class_def = ClassDefinition(node.findAncestor { |n| n.kind_of? ClassDefinition })
      klass_type = MirrorType(@builder.typer.getInferredType(enclosing_class_def).resolve)
      @captured_fields.each do |field:String|
        field_type = klass_type.getDeclaredField(field).returnType # TODO, maybe check this exists?

        type_ref = TypeRefImpl.new(field_type.name, JVMTypeUtils.isArray(field_type), false, nil)
        getter_name = "z_get_#{field}"
        setter_name = "z_set_#{field}"
        getter_not_declared_yet = klass_type.getDeclaredMethods(getter_name).isEmpty
        setter_not_declared_yet = klass_type.getDeclaredMethods(setter_name).isEmpty
        if setter_not_declared_yet
          args = Arguments.new(enclosing_class_def.position,
                               [RequiredArgument.new(SimpleString.new(field), type_ref)], Collections.emptyList, nil, Collections.emptyList, nil)
          body = FieldAssign.new(SimpleString.new(field), LocalAccess.new(SimpleString.new(field)), nil)
    
          setter_mdef = MethodDefinition.new(SimpleString.new(setter_name), args, SimpleString.new('void'), [body], nil)

          anno = Annotation.new(args.position, Constant.new(SimpleString.new('org.mirah.jvm.types.Modifiers')),
                             [HashEntry.new(SimpleString.new('flags'), Array.new([SimpleString.new('BRIDGE')]))])
          setter_mdef.annotations.add(anno)
          enclosing_class_def.body.add(
            setter_mdef
          )
          @builder.typer.infer setter_mdef
        end
        if getter_not_declared_yet
          args = Arguments.new(enclosing_class_def.position, [], Collections.emptyList, nil, Collections.emptyList, nil)
          body = FieldAccess.new(SimpleString.new(field))
    
          getter_mdef = MethodDefinition.new(SimpleString.new(getter_name), args, type_ref, [body], nil)
          anno = Annotation.new(args.position, Constant.new(SimpleString.new('org.mirah.jvm.types.Modifiers')),
                             [HashEntry.new(SimpleString.new('flags'), Array.new([SimpleString.new('BRIDGE')]))])
          getter_mdef.annotations.add(anno)
          enclosing_class_def.body.add(
            getter_mdef
          )
          @builder.typer.infer getter_mdef
        end
      end
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

    # if self captured
    # add entry for self
    if @captured_self
      # selftype might be wrong for methods, but lets see.
      self_type = @parent_scope.selfType.resolve
      var_type_name = self_type.name
      variable_type_ref  = TypeRefImpl.new(var_type_name, false, false, node.position)
      
      entries.add HashEntry.new(SimpleString.new("self"), variable_type_ref)
    end

    attr_def = FunctionalCall.new(
      SimpleString.new("attr_accessor"),
      [Hash.new(node.position, entries)],
      nil)
    binding_klass.body.insert(0, attr_def)

    binding_new_call = Call.new(node.position, Constant.new(SimpleString.new(name)), SimpleString.new("new"), [], nil)

    assign_binding_dot_new = LocalAssignment.new(
        node.position,
        SimpleString.new(@bindingName),
        binding_new_call)

    @@log.fine "inserted binding assign / binding class"
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

    mdef = node.findAncestor { |n| n.kind_of? MethodDefinition }
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
         # insert after binding class & binding instantiation
         # if we were less lazy, we'd find the binding construction, and insert after
        NodeList(node).insert 2, addition

        @builder.infer addition
      end
    end

    if @captured_self
      addition = Call.new(blockAccessNode(node.position),
      SimpleString.new("self_set"),
      [Self.new(node.position)],
      nil)
      NodeList(node).insert 2, addition
      @builder.infer addition
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

  # If self has been captured, then ensure that it is replaced with a binding ref
  def exitSelf(selfNode, blah)
    return nil unless false # selfCaptured

    @@log.finest "exitSelf: replacing self with #{@bindingName}.self"
    
    maybeNoteBlockBinding

    replacement = Call.new(
        blockAccessNode(selfNode.position),
        SimpleString.new("self"),
        [],
        nil
      )

    replaceSelf(selfNode, replacement)

    @builder.typer.learnType replacement.target, @binding_type

    @@log.fine "does replacement have parent?: #{replacement.parent}"
    @@log.fine "does replacement parent 0th child: #{NodeList(replacement.parent).get(0)}" if replacement.parent.kind_of? NodeList
    @@log.fine "does replacement have parent?: #{replacement.parent.parent}" if replacement.parent
    @builder.typer.infer replacement
  end

  def is_binding_field name: String
    name.startsWith "$b"
  end

  def exitFieldAccess(fieldAccess, blah)
    field_name = fieldAccess.name.identifier
    return nil unless @captured_fields.contains field_name

    @@log.finest "exitFieldAccess: replacing #{field_name} with #{@bindingName}.self.z_get_#{field_name}"
    #@@log.finest "  Type: #{@builder.typer.getInferredType(local)}"

    maybeNoteBlockBinding

    replacement = Call.new(
      Call.new(
        blockAccessNode(fieldAccess.position),
        SimpleString.new("self"),
        [],
        nil
      ),
      SimpleString.new("z_get_#{field_name}"),
      [],
      nil
    )

    replaceSelf(fieldAccess, replacement)

    @builder.typer.learnType replacement.target, @binding_type

    @@log.fine "does replacement have parent?: #{replacement.parent}"
    @@log.fine "does replacement parent 0th child: #{NodeList(replacement.parent).get(0)}" if replacement.parent.kind_of? NodeList
    @@log.fine "does replacement have parent?: #{replacement.parent.parent}" if replacement.parent
    @builder.typer.infer replacement
  end


  def exitFieldAssign(fieldAssignment, blah)
    return nil # TODO make it work
    field_name = fieldAssignment.name.identifier
    return nil unless @captured_fields.contains field_name

    @@log.finest "exitFieldAssignment: replacing #{field_name} with #{@bindingName}.self.z_set_#{field_name}="
    #@@log.finest "  Type: #{@builder.typer.getInferredType(field_name)}"


    maybeNoteBlockBinding

    new_value = Node(fieldAssignment.value)
    new_value.setParent(nil)

    replacement = Call.new(
      Call.new(
        blockAccessNode(fieldAssignment.position),
        SimpleString.new("self"),
        [],
        nil
      ),
      SimpleString.new("z_set_#{field_name}"),
      [new_value],
      nil
      )
    replaceSelf(fieldAssignment, replacement)
    fieldAssignment.value.setParent replacement

    @builder.typer.learnType replacement.target, @binding_type
    @builder.typer.infer new_value
    @builder.typer.infer replacement
  end

  def exitLocalAssignment(local, blah)
    local_name = local.name.identifier
    return nil unless @captured.contains local_name

    @@log.finest "exitLocalAssignment: replacing #{local.name.identifier} with #{@bindingName}.#{local.name.identifier}="
    @@log.finest "  Type: #{@builder.typer.getInferredType(local)}"

    maybeNoteBlockBinding

    new_value = Node(local.value)
    new_value.setParent(nil)
    replacement = Call.new(
      blockAccessNode(local.position),
      SimpleString.new("#{local.name.identifier}_set"),
      [new_value],
      nil)

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