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

package org.mirah.jvm.compiler

import java.io.File
import java.util.Collections
import java.util.LinkedList
import org.mirah.util.Logger
import mirah.lang.ast.*
import org.mirah.util.Context
import org.mirah.jvm.types.JVMType

import org.objectweb.asm.ClassWriter
import org.objectweb.asm.Opcodes
import org.objectweb.asm.commons.Method

class ClassCompiler < BaseCompiler implements InnerClassCompiler
  def self.initialize:void
    @@log = Logger.getLogger(ClassCompiler.class.getName)
  end
  def initialize(context:Context, classdef:ClassDefinition)
    super(context)
    @classdef = classdef
    @fields = {}
    @innerClasses = LinkedList.new
    @type = getInferredType(@classdef)
  end
  def initialize(context:Context, classdef:ClassDefinition, outerClass:JVMType, method:Method)
    initialize(context, classdef)
    @outerClass = outerClass
    @enclosingMethod = method
  end  
  
  def compile:void
    @@log.fine "Compiling class #{@classdef.name.identifier}"
    startClass
    visit(@classdef.body, nil)
    @classwriter.visitEnd
    @@log.fine "Finished class #{@classdef.name.identifier}"
  end

  def getInternalName(type:JVMType)
    type.getAsmType.getInternalName
  end

  def visitClassAppendSelf(node, expression)
    saved = @static
    @static = true
    visit(node.body, expression)
    @static = saved
    nil
  end
  
  def visitMethodDefinition(node, expression)
    isStatic = @static || node.kind_of?(StaticMethodDefinition)
    constructor = isStatic && "initialize".equals(node.name.identifier)
    name = constructor ? "<clinit>" : node.name.identifier.replaceFirst("=$", "_set")
    method = MethodCompiler.new(self, @type, methodFlags(node, isStatic), name)
    method.compile(@classwriter, node)
  end
  
  def visitStaticMethodDefinition(node, expression)
    visitMethodDefinition(node, expression)
  end
  
  def visitConstructorDefinition(node, expression)
    method = MethodCompiler.new(self, @type, Opcodes.ACC_PUBLIC, "<init>")
    method.compile(@classwriter, node)
  end
  
  def visitClassDefinition(node, expression)
    compileInnerClass(node, nil)
  end
  
  def visitInterfaceDeclaration(node, expression)
    compileInnerInterface(node, nil)
  end
  
  def compileInnerClass(node:ClassDefinition, method:Method):void
    compiler = ClassCompiler.new(context, node, @type, method)
    @innerClasses.add(compiler)
    # TODO only supporting anonymous inner classes for now.
    @classwriter.visitInnerClass(compiler.internal_name, nil, nil, 0)
    compiler.compile
  end
  
  def compileInnerInterface(node:InterfaceDeclaration, method:Method):void
    compiler = InterfaceCompiler.new(context, node, @type, method)
    @innerClasses.add(compiler)
    # TODO only supporting anonymous inner classes for now.
    @classwriter.visitInnerClass(compiler.internal_name, nil, nil, 0)
    compiler.compile
  end
  
  def getBytes:byte[]
    # TODO CheckClassAdapter
    @classwriter.toByteArray
  end
  
  def startClass:void
    # TODO: need to support widening before we use COMPUTE_FRAMES
    jvm = context[JvmVersion]
    @classwriter = MirahClassWriter.new(context, jvm.flags)
    @classwriter.visit(jvm.version, flags, internal_name, nil, superclass, interfaces)
    filename = self.filename
    @classwriter.visitSource(filename, nil) if filename
    if @outerClass
      method = @enclosingMethod.getName if @enclosingMethod
      desc = @enclosingMethod.getDescriptor if @enclosingMethod
      @classwriter.visitOuterClass(getInternalName(@outerClass), method, desc)
    end
    context[AnnotationCompiler].compile(@classdef.annotations, @classwriter)
  end
  
  def visitFieldDeclaration(node, expression)
    flags = calculateFlagsFromAnnotations(Opcodes.ACC_PRIVATE, node.annotations)
    initial_value = nil
    if !node.value.nil? && (flags&(Opcodes.ACC_FINAL|Opcodes.ACC_STATIC))==Opcodes.ACC_FINAL|Opcodes.ACC_STATIC
      if node.type.typeref.name.equals('long') 
        initial_value = Long.new(mirah::lang::ast::Fixnum(node.value).value)
      else # If you want to support more types of final static fields, add type handling here
        raise "Cannot support field declaration #{node} with value #{node.value}: node.type.typeref.name=#{node.type.typeref.name}." 
      end
    end
    fv = @classwriter.visitField(flags, node.name.identifier, getInferredType(node).getAsmType.getDescriptor, nil, initial_value)
    context[AnnotationCompiler].compile(node.annotations, fv)
    fv.visitEnd
  end
  
  def flags
    calculateFlagsFromAnnotations(Opcodes.ACC_PUBLIC, @classdef.annotations) | Opcodes.ACC_SUPER
  end
  
  def methodFlags(mdef:MethodDefinition, isStatic:boolean)
    flags = calculateFlagsFromAnnotations(Opcodes.ACC_PUBLIC, mdef.annotations)
    if isStatic
      flags | Opcodes.ACC_STATIC
    else
      flags
    end
  end
  
  def internal_name
    getInternalName(@type)
  end
  
  def filename
    if @classdef.position
      path = @classdef.position.source.name
      lastslash = path.lastIndexOf(File.separatorChar)
      if lastslash == -1
        return path
      else
        return path.substring(lastslash + 1)
      end
    end
    nil
  end
  
  def superclass
    getInternalName(@type.superclass) if @type.superclass
  end
  
  def interfaces
    size = @classdef.interfaces.size
    array = String[size]
    i = 0
    size.times do |i|
      node = @classdef.interfaces.get(i)
      array[i] = getInternalName(getInferredType(node))
    end
    array
  end
  
  def innerClasses
    Collections.unmodifiableCollection(@innerClasses)
  end
end