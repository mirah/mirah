# Copyright (c) 2013 The Mirah project authors. All Rights Reserved.
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

package org.mirah.jvm.compiler

import mirah.lang.ast.*
import org.mirah.typer.Typer
import org.mirah.typer.BlockFuture
import org.mirah.typer.MethodFuture
import org.mirah.typer.MethodType
import org.mirah.typer.TypeFuture
import org.mirah.typer.ResolvedType
import org.mirah.typer.Scope
import org.mirah.typer.simple.TypePrinter
import org.mirah.macros.Compiler as MacroCompiler
import org.mirah.util.AstFormatter
import org.mirah.util.Context
import java.util.logging.Level
import java.util.logging.Logger

import java.util.Collections
import java.util.Stack
import java.util.ArrayList
import java.io.File

class ClosureTransformer < NodeScanner
  def self.initialize:void
    @@log = Logger.getLogger(ClosureTransformer.class.getName)
  end
  
  def initialize(context: Context)
    @context = context
    @typer = context[Typer]
    @parser = context[MacroCompiler]
    @nlr_transformer = NLRTransformer.new context
    @regular_transformer = RegularTransformer.new context
    @method_stack = Stack.new
  end

  def enterMethodDefinition(node, arg)
    @method_stack.push StackEntry.new node
    true
  end

  def enterStaticMethodDefinition(node, arg)
    @method_stack.push StackEntry.new node
    true
  end

  def enterScript(node, arg)
    @method_stack.push StackEntry.new node
    true
  end

  def exitMethodDefinition(node, arg)
    exit_method(node, arg)
    node
  end

  def exitStaticMethodDefinition(node, arg)
    exit_method(node, arg)
    node
  end
  def exitScript(node, arg)
    exit_method(node, arg)
    node
  end

#    position = node.position
#    nlr_exception_name = Constant.new(position, SimpleString.new(position, "CoolException"))
#    body = node.body
#    new_body = @parser.quote do
#      begin
#        `body`
#      rescue `nlr_exception_name` => returnable
#        return returnable.return_value
#      end
#    end 
  def exit_method(node: Node, arg: Object): void 
    result = StackEntry(@method_stack.pop)
    unless result.had_block?
      puts "No block in #{node}"
      return
    end

    if result.has_non_local_returns?
      puts "#{node} contains non local returns"
      @nlr_transformer.reset_exception
      node.accept @nlr_transformer, result.node
    else
      node.accept @regular_transformer, result.node
    end
  end

  def enterBlock(node, arg)
    peek_stack.enter_block!
    true
  end

  def exitBlock(node, arg)
    peek_stack.exit_block!
    node
  end

  def enterReturn(node, arg)
    peek_stack.maybe_inc_non_local_returns
    true
  end

  def peek_stack
    StackEntry(@method_stack.peek)
  end

  class StackEntry
    def initialize node: Node
      @node = node
      @nlr_returns = 0
      @in_block = false
      @had_block = false
    end
    def node
      @node
    end
    def maybe_inc_non_local_returns
      @nlr_returns+=1 if in_block?
    end
    def has_non_local_returns?
      @nlr_returns > 0
    end
    def enter_block!
      @in_block = true
      @had_block = true
    end
    def exit_block!
      @in_block = false
    end
    def in_block?
      @in_block
    end
    def had_block?
      @had_block
    end
  end



      #closure_definition.body.add @parser.quote do
        #          def initialize(binding: `method_scope.binding_type`) # can't do this because Unquote handling doesn't deal with it
        #            @binding = binding
        #          end
      #  def `mtype.name`(`args`)
      #    `node.body`
      #  end
      #end
# it'd be nice if this worked
#      new_body = @parser.quote do
#        begin
#          `body`
#        rescue `nlr_exception_name` => returnable
#          return returnable.return_value
#        end
#      end
      # @parser.quote { `ClassDefinition(closure_definition).name`.new(`BindingReference.new`) }
#        klass.body.add @parser.quote do
          #        def initialize(return_value: `@typer.infer(node).resolve.name`) # TODO constant unquote
          #          @return_value = return_value
          #        end
#          def return_value; @return_value; end
          # empty fillInStackTrace should force JVM to skip trace building
#          def fillInStackTrace; end
#        end

  class NLRTransformer < NodeScanner
    def initialize(context: Context)
      @context = context
      @typer = context[Typer]
      @scoper = @typer.scoper
      @parser = @typer.macro_compiler
    end

    def reset_exception
      @nlr_exception_class = ClassDefinition(nil)
    end

    def enterScript(node, arg)
      maybe_build_nlr_exception node, arg
      true
    end

    def enterMethodDefinition(node, arg)
      maybe_build_nlr_exception node, arg
      true
    end

    def enterStaticMethodDefinition(node, arg)
      maybe_build_nlr_exception node, arg
      true
    end

    def maybe_build_nlr_exception(node: Node, arg: Object): void
      if arg == node
        @nlr_exception_class = build_nlr_exception(node)
        body = Utils.enclosing_body node
        Utils.insert_in_front body, @nlr_exception_class
        infer @nlr_exception_class
      end
    end

    def exitScript(node, arg)
      exit_method(node, arg)
      node # don't get why this is necessary
    end

    def exitMethodDefinition(node, arg)
      exit_method(node, arg)
      node # don't get why this is necessary
    end

    def exitStaticMethodDefinition(node, arg)
      exit_method(node, arg)
      node # don't get why this is necessary
    end

    def enterBlock(node, arg)
      @in_block = true
      true
    end

    def enterReturn(node, arg)
      return false unless @in_block
      replace_return_with_nlr_raise node
      true
    end

    def exitBlock(node, arg)
      @in_block = false
      build_and_inject_closure node
      node
    end

    def exit_method(node: Node, arg: Object): void
      return unless arg == node
      body = Utils.enclosing_body node

      nlr_exception_name = @nlr_exception_class.name
      return_value_type = if node.kind_of? MethodDefinition
                            MethodType(@typer.infer(node).resolve).returnType
                          elsif node.kind_of? Script
                            @typer.infer(node).resolve
                          end
      puts "return value of #{node}: #{return_value_type} is void? #{void_type? return_value_type}"
      return_value = unless void_type? return_value_type
                       Node(Call.new(node.position, 
                                     LocalAccess.new(SimpleString.new 'return_exception'), 
                                     SimpleString.new("return_value"),
                                     Collections.emptyList,
                                     nil 
                                     ))
                     else
                       Node(ImplicitNil.new)
                     end
      new_body = Rescue.new(node.position, [],
                            [
                             RescueClause.new(
                                              node.position,
                                              [nlr_exception_name],
                                              SimpleString.new('return_exception'),
                                              [Return.new(node.position, return_value)]
                                              )
                            ],
                            nil
                            )
      new_body.body = body
      real_new_body = NodeList.new(node.position, [new_body])
      if node.kind_of? Script
        Script(node).body = real_new_body
      else
        MethodDefinition(node).body = real_new_body
      end
      @typer.infer real_new_body
    end

    def infer node: Node
      @typer.infer node
    end

    def build_and_inject_closure node: Block
      ancestor = Utils.find_enclosing_method_node node
      enclosing_body = Utils.enclosing_body ancestor

      method_scope = @scoper.getScope(enclosing_body)
      method_scope.binding_type ||= begin
                                      binding_klass = build_binding node
                                      Utils.insert_in_front enclosing_body, binding_klass
                                      infer(binding_klass).resolve
                                    end
      
      future = BlockFuture(@typer.getInferredType node)
      closure_definition = Utils.build_class node.position, future.resolve, build_temp_name("Closure", node)

      closure_definition.body.add Utils.build_closure_constructor(node.position, method_scope.binding_type)

      mtype = future.basic_block_method_type
      args = if node.arguments
               Arguments(node.arguments.clone)
             else
               Arguments.new(node.position,
                             Collections.emptyList,
                             Collections.emptyList, nil, Collections.emptyList, nil)
             end
      while args.required.size < mtype.parameterTypes.size
        arg = RequiredArgument.new(node.position,
                                   SimpleString.new("arg#{args.required.size}"), nil)
        args.required.add(RequiredArgument(arg)) #??? I'm not sure why I needed this cast
      end

      return_type = Utils.makeTypeName(node.position, mtype.returnType)
      method = MethodDefinition.new(node.position, SimpleString.new(mtype.name), args, return_type, nil, nil)
      method.body = NodeList(node.body.clone)

      set_parent_scope method, @scoper.getScope(node)
      closure_definition.body.add method

      Utils.insert_in_front enclosing_body, closure_definition
      infer(closure_definition)
      new_closure = Utils.closure_call_node node.position, ClassDefinition(closure_definition)
      infer new_closure
      Utils.replace_block_with_closure_in_call CallSite(node.parent),
                                               node, new_closure

      node
    end

  def self.initialize:void
    @@log = Logger.getLogger(ClosureTransformer.class.getName)
  end

    def replace_return_with_nlr_raise(node: Return): void
      nlr_exception_name = @nlr_exception_class.name
      raise_expression = if node.value.kind_of? ImplicitNil
                           @parser.quote { raise `nlr_exception_name`.new }
                         else
                           @parser.quote { raise `nlr_exception_name`.new `node.value` }
                         end
      @@log.finest "replacing return with raise #{nlr_exception_name}"
      node.parent.replaceChild node, raise_expression


        buf = java::io::ByteArrayOutputStream.new
        ps = java::io::PrintStream.new(buf)
        printer = TypePrinter.new(@typer, ps)
        printer.scan(raise_expression, nil)
        ps.close()
      @@log.finest("before intypes for raise expr:\n#{String.new(buf.toByteArray)}")

      infer raise_expression

        buf = java::io::ByteArrayOutputStream.new
        ps = java::io::PrintStream.new(buf)
        printer = TypePrinter.new(@typer, ps)
        printer.scan(raise_expression, nil)
        ps.close()
      @@log.finest("Inferred types for raise expr:\n#{String.new(buf.toByteArray)}")

    end

    def build_temp_name(middle_fix: String, block: Node): String
      @scoper.getScope(block).temp("#{Utils.build_name_prefix(block)}$#{middle_fix}")
    end 

    def set_parent_scope method: MethodDefinition, parent_scope: Scope
      @scoper.addScope(method).parent = parent_scope
    end

    def build_binding(node: Block): ClosureDefinition
      md = node.findAncestor(MethodDefinition.class)
      mt = MethodFuture(@typer.infer(md))
      klass_name = build_temp_name "Binding", node
      
      klass = Utils.build_class(node.position, ResolvedType(nil), klass_name)
      klass
    end

    def void_type? type: ResolvedType
      void_type.equals type
    end

    def void_type
      @typer.type_system.getVoidType.resolve
    end

    def build_nlr_exception(node: Node): ClassDefinition
      puts "building exception #{node}"
      klass = Utils.build_class node.position,
                          @typer.type_system.getBaseExceptionType.resolve,
                          build_temp_name("NonLocalReturn", node)
      return_value_type = if node.kind_of? MethodDefinition
                            MethodType(@typer.infer(node).resolve).returnType
                          elsif node.kind_of? Script
                            void_type
                          end
      puts "return building nlr exception #{return_value_type}"
      # empty fillInStackTrace should force JVM to skip trace building
      klass.body.add @parser.quote { def fillInStackTrace; end }
      unless void_type? return_value_type
        klass.body.add @parser.quote { def return_value; @return_value; end }
      end

      required_constructor_arguments = unless void_type? return_value_type
        [RequiredArgument.new(SimpleString.new('return_value'),
                              SimpleString.new(return_value_type.name))]
      else
        Collections.emptyList
      end
      args = Arguments.new(node.position,
                           required_constructor_arguments,
                           Collections.emptyList, nil, Collections.emptyList, nil)
      body = unless void_type? return_value_type
               #[@parser.quote { @return_value = return_value }]
               [FieldAssign.new(SimpleString.new('return_value'), LocalAccess.new(SimpleString.new('return_value')), nil)]
             else
               Collections.emptyList
             end
      constructor = ConstructorDefinition.new(SimpleString.new('initialize'), args, SimpleString.new('void'), body, nil)
      klass.body.add(constructor)
      infer klass
      ClassDefinition(klass)
    end
  end

  class RegularTransformer < NodeScanner
    def initialize(context: Context)
      @context = context
      @typer = context[Typer]
      @scoper = @typer.scoper
      @parser = @typer.macro_compiler
    end

    def exitBlock(node, arg)
      puts "injecting regular closure"
      build_and_inject_closure node
      node
    end

    def infer node: Node
      @typer.infer node
    end

    def build_and_inject_closure node: Block
      ancestor = Utils.find_enclosing_method_node node
      enclosing_body = Utils.enclosing_body ancestor

      method_scope = @scoper.getScope(enclosing_body)
      method_scope.binding_type ||= begin
                                      binding_klass = build_binding node
                                      Utils.insert_in_front enclosing_body, binding_klass
                                      infer(binding_klass).resolve
                                    end
      
      future = BlockFuture(@typer.getInferredType node)
      closure_definition = Utils.build_class node.position, future.resolve, build_temp_name("Closure", node)

      closure_definition.body.add Utils.build_closure_constructor(node.position, method_scope.binding_type)


if contains_methods node
  copy_methods closure_definition, node, method_scope
else

      mtype = future.basic_block_method_type
      args = if node.arguments
               Arguments(node.arguments.clone)
             else
               Arguments.new(node.position,
                             Collections.emptyList,
                             Collections.emptyList, nil, Collections.emptyList, nil)
             end
      while args.required.size < mtype.parameterTypes.size
        arg = RequiredArgument.new(node.position,
                                   SimpleString.new("arg#{args.required.size}"), nil)
        args.required.add(RequiredArgument(arg)) #??? I'm not sure why I needed this cast
      end

      return_type = Utils.makeTypeName(node.position, mtype.returnType)
      method = MethodDefinition.new(node.position, SimpleString.new(mtype.name), args, return_type, nil, nil)
      method.body = NodeList(node.body.clone)
end

      set_parent_scope method, @scoper.getScope(node)
      closure_definition.body.add method

      Utils.insert_in_front enclosing_body, closure_definition
      infer(closure_definition)

      new_closure = Utils.closure_call_node node.position, ClassDefinition(closure_definition)
      Utils.replace_block_with_closure_in_call CallSite(node.parent), node, new_closure

      infer new_closure
      node
    end

    def build_temp_name(middle_fix: String, block: Node): String
      @scoper.getScope(block).temp("#{Utils.build_name_prefix(block)}$#{middle_fix}")
    end 

    def set_parent_scope method: MethodDefinition, parent_scope: Scope
      @scoper.addScope(method).parent = parent_scope
    end

    def build_binding(node: Block): ClosureDefinition
      md = node.findAncestor(MethodDefinition.class)
      mt = MethodFuture(@typer.infer(md))
      klass_name = build_temp_name "Binding", node
      
      klass = Utils.build_class(node.position, ResolvedType(nil), klass_name)
      klass
    end

  # Returns true if any MethodDefinitions were found.
  def contains_methods(block: Block): boolean
    block.body_size.times do |i|
      node = block.body(i)
      return true if node.kind_of?(MethodDefinition)
    end
    return false
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

  end

  class Utils
    def self.build_closure_constructor position: Position, binding_type: ResolvedType
      args = Arguments.new(position,
                           [RequiredArgument.new(SimpleString.new('binding'),
                                                 Utils.makeTypeName(position,
                                                              binding_type))],
                           Collections.emptyList, nil, Collections.emptyList, nil)
      body = FieldAssign.new(SimpleString.new('binding'), LocalAccess.new(SimpleString.new('binding')), nil)
      ConstructorDefinition.new(SimpleString.new('initialize'),
                                args,
                                SimpleString.new('void'),
                                [body],
                                nil)
    end

    def self.closure_call_node position: Position, klass: ClassDefinition
        Call.new(position,
                             klass.name,
                             SimpleString.new("new"),
                             [BindingReference.new],
                 nil)
    end
    def self.replace_block_with_closure_in_call(parent: CallSite, block: Block, new_node: Node): void
      if block == parent.block
        parent.block = nil
        parent.parameters.add(new_node)
      else
        new_node.setParent(nil)
        parent.replaceChild(block, new_node)
      end
    end


    def self.find_enclosing_method_node block: Node
      class_or_script = block.findAncestor MethodDefinition.class
      class_or_script ||= block.findAncestor Script.class
      return class_or_script
    end

    def self.find_enclosing_node block: Node
      class_or_script = block.findAncestor ClassDefinition.class
      class_or_script ||= block.findAncestor Script.class
      return class_or_script
    end

    def self.insert_in_front nodes: NodeList, new_node: Node
      nodes.insert(0, new_node)
    end

    def self.enclosing_body ancestor: Node
      if ancestor.kind_of?(MethodDefinition)
        NodeList(MethodDefinition(ancestor).body)
      else
        NodeList(Script(ancestor).body)
      end
    end

    # Builds an anonymous class.
    def self.build_class(position: Position, parent_type: ResolvedType, name: String=nil)
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

    def self.makeTypeName(position: Position, type: ResolvedType): Constant
      Constant.new(position, SimpleString.new(position, type.name))
    end


    def self.build_name_prefix block: Node
      class_or_script = Utils.find_enclosing_node block
      
      outer_name = if class_or_script.kind_of? ClassDefinition
                     ClassDefinition(class_or_script).name.identifier
                   else
                     source_name = class_or_script.position.source.name || 'DashE'
                     id = ""
                     id_split_on_dash = File.new(source_name).getName.
                       replace("\.duby|\.mirah", "").
                       split("[_-]")
                     #                     .each do |word|
                     #                         id += word.substring(0,1).toUpperCase + word.substring(1)
                     #                      end
                     i = 0
                     while i < id_split_on_dash.length
                       word = id_split_on_dash[i]
                       id += word.substring(0,1).toUpperCase + word.substring(1)
                       i += 1
                     end
                     id
                   end
    end
  end
end
