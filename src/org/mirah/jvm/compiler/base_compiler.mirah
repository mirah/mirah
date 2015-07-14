# Copyright (c) 2015 The Mirah project authors. All Rights Reserved.
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

import org.mirah.util.Logger
import java.util.logging.Level
import java.util.List
import javax.tools.DiagnosticListener
import mirah.lang.ast.Annotation
import mirah.lang.ast.AnnotationList
import mirah.lang.ast.Array
import mirah.lang.ast.HashEntry
import mirah.lang.ast.Identifier
import mirah.lang.ast.MethodDefinition
import mirah.lang.ast.Node
import mirah.lang.ast.Position
import mirah.lang.ast.SimpleNodeVisitor
import mirah.lang.ast.TypeRefImpl
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.MemberKind
import org.mirah.util.Context
import org.mirah.util.MirahDiagnostic
import org.mirah.typer.ErrorType
import org.mirah.typer.MethodType
import org.mirah.typer.Typer
import org.mirah.typer.Scope
import org.mirah.typer.Scoper
import org.mirah.typer.UnreachableType
import org.objectweb.asm.Type
import org.objectweb.asm.Opcodes
import org.objectweb.asm.commons.Method

class ReportedException < RuntimeException
  def initialize(ex:Throwable)
    super(ex)
  end
end

class BaseCompiler < SimpleNodeVisitor
  attr_reader context:Context, typer:Typer, scoper:Scoper
  
  def initialize(context:Context)
    @context = context
    @typer = context[Typer]
    @scoper = @typer.scoper
  end
  
  def self.initialize:void
    @@ACCESS = {
      PUBLIC: Opcodes.ACC_PUBLIC,
      PRIVATE: Opcodes.ACC_PRIVATE,
      PROTECTED: Opcodes.ACC_PROTECTED,
      DEFAULT: 0
    }
    @@FLAGS = {
      STATIC: Opcodes.ACC_STATIC,
      FINAL: Opcodes.ACC_FINAL,
      SUPER: Opcodes.ACC_SUPER,
      SYNCHRONIZED: Opcodes.ACC_SYNCHRONIZED,
      VOLATILE: Opcodes.ACC_VOLATILE,
      BRIDGE: Opcodes.ACC_BRIDGE,
      VARARGS: Opcodes.ACC_VARARGS,
      TRANSIENT: Opcodes.ACC_TRANSIENT,
      NATIVE: Opcodes.ACC_NATIVE,
      INTERFACE: Opcodes.ACC_INTERFACE,
      ABSTRACT: Opcodes.ACC_ABSTRACT,
      STRICT: Opcodes.ACC_STRICT,
      SYNTHETIC: Opcodes.ACC_SYNTHETIC,
      ANNOTATION: Opcodes.ACC_ANNOTATION,
      ENUM: Opcodes.ACC_ENUM,
      DEPRECATED: Opcodes.ACC_DEPRECATED
    }
    @@log = Logger.getLogger(BaseCompiler.class.getName)
  end
  
  def reportError(message:String, position:Position)
    @context[DiagnosticListener].report(MirahDiagnostic.error(position, message))
  end
  
  def reportNote(message:String, position:Position)
    @context[DiagnosticListener].report(MirahDiagnostic.note(position, message))
  end
  
  def reportWarning(message:String, position:Position)
    @context[DiagnosticListener].report(MirahDiagnostic.warning(position, message))
  end

  def reportICE(ex:Throwable, position:Position):RuntimeException
    if ex.kind_of?(ReportedException)
      raise ex
    elsif ex.getCause.kind_of?(ReportedException)
      raise ex.getCause
    # For test running, otherwise you get Internal compiler error over and over
    elsif ex.getClass.getName.equals "org.jruby.exceptions.RaiseException"
      raise ex
    else
      @@log.log Level.SEVERE, "Exception in compiler for #{position}", ex
      reportError("Internal error in compiler: #{ex} #{ex.getMessage}", position)
      
     # @diagnostics.report(MirahDiagnostic.error(position, "Internal compiler error: #{ex} #{ex.getMessage}"))
      
      raise ReportedException.new(ex)
    end
    RuntimeException(nil)  # unreachable
  end

  def getInferredType(node:Node):JVMType
    type = @typer.getInferredType(node).resolve
    return nil if type.kind_of?(UnreachableType)
    if type.kind_of?(ErrorType)
      reportError(ErrorType(type).message.toString, node.position)
    end
    JVMType(type)
  rescue Exception => ex
    @@log.log Level.SEVERE, "this node: #{node}, #{node.position}"
    raise reportICE(ex, node.position)
  end

  def getInferredType(mdef:MethodDefinition):MethodType
    MethodType(typer.getInferredType(mdef).resolve)
  rescue Exception => ex
    raise reportICE(ex, mdef.name.position)
  end

  def methodDescriptor(name:String, returnType:JVMType, argTypes:List):Method
    args = Type[argTypes.size]
    args.length.times do |i|
      begin
        args[i] = JVMType(argTypes[i]).getAsmType
      rescue ClassCastException
        error = ErrorType(argTypes[i])
        e = List(error.message.get(0))
        ex = IllegalArgumentException.new(String(e.get(0)))
        raise reportICE(ex, Position(e.get(1)))
      end
    end
    Method.new(name, returnType.getAsmType, args)
  end

  def methodDescriptor(method:JVMMethod):Method
    returnType = method.returnType.getAsmType
    name = method.name
    if MemberKind.CONSTRUCTOR == method.kind
      name = '<init>'
      returnType = Type.VOID_TYPE
    elsif MemberKind.STATIC_INITIALIZER == method.kind
      name = '<clinit>'
      returnType = Type.VOID_TYPE      
    end
    argTypes = method.argumentTypes
    args = Type[argTypes.size]
    args.length.times do |i|
      args[i] = JVMType(argTypes[i]).getAsmType
    end
    Method.new(name, returnType, args)
  end

  def getScope(node:Node):Scope
    @scoper.getScope(node)
  end

  def getIntroducedScope(node:Node):Scope
    @scoper.getIntroducedScope(node)
  end

  def defaultNode(node, arg)
    reportError("#{getClass.getSimpleName} can't compile node #{node.getClass.getSimpleName}",
                node.position)
  end

  def visit(node:Node, arg:Object):void
    begin
      node.accept(self, arg)
    rescue ReportedException => ex
      raise ex
    rescue Throwable => ex
      raise reportICE(ex, node.position)
    end
  end

  def visitNodeList(nodes, expression)
    size = nodes.size
    last = size - 1
    size.times do |i|
      visit(nodes.get(i), i < last ? nil : expression)
    end
  end
  
  def visitPackage(node, arg)
    visit(node.body, arg) if node.body
  end
  
  def visitImport(node, arg)
  end
  
  def visitNoop(node, arg)
  end
  
  def visitUnquote(node, arg)
    node.nodes.each {|n: Node| visit(n, arg)}
  end
  
  def findType(name:String):JVMType
    JVMType(@typer.type_system.get(nil, TypeRefImpl.new(name, false, false, nil)).resolve)
  end
  
  def visitMacroDefinition(node, expression)
    # ignore. It was already compiled
  end
  
  def calculateFlagsFromAnnotations(defaultAccess:int, annotations:AnnotationList):int
    access = defaultAccess
    flags = 0
    annotations.each do |anno: Annotation|
      next unless "org.mirah.jvm.types.Modifiers".equals(anno.type.typeref.name)
      anno.values.each do |entry: HashEntry|
        key = Identifier(entry.key).identifier
        if "access".equals(key)
          #access = @@ACCESS[Identifier(entry.value).identifier] # TODO better boxing
          access = Integer(@@ACCESS[Identifier(entry.value).identifier]).intValue
        elsif "flags".equals(key) # TODO better boxing
          values = Array(entry.value)
          values.values.each do |id: Identifier| # cast from Node
            flag = id.identifier
            # flags |= @@FLAGS[flag]
            flags |= Integer(@@FLAGS[flag]).intValue
          end
        else
          raise "unknown modifier entry: #{entry}"
        end
      end
    end
    flags | access
  end
end