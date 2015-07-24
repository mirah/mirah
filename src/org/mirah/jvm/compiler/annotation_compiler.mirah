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

import java.util.Collections
import org.mirah.util.Logger
import mirah.lang.ast.*
import org.objectweb.asm.AnnotationVisitor
import org.objectweb.asm.ClassVisitor
import org.objectweb.asm.FieldVisitor
import org.objectweb.asm.MethodVisitor
import org.mirah.jvm.types.JVMType
import org.mirah.typer.TypeSystem
import org.mirah.util.Context

interface AnnotationVisitorFactory
  def create(type:String, runtime:boolean):AnnotationVisitor; end
end

class ClassAnnotationFactory implements AnnotationVisitorFactory
  def initialize(visitor:ClassVisitor)
    @visitor = visitor
  end

  def create(type, runtime)
    @visitor.visitAnnotation(type, runtime)
  end
end

class MethodAnnotationFactory implements AnnotationVisitorFactory
  def initialize(visitor:MethodVisitor)
    @visitor = visitor
  end

  def create(type, runtime)
    @visitor.visitAnnotation(type, runtime)
  end
end

class FieldAnnotationFactory implements AnnotationVisitorFactory
  def initialize(visitor:FieldVisitor)
    @visitor = visitor
  end

  def create(type, runtime)
    @visitor.visitAnnotation(type, runtime)
  end
end

class AnnotationCompiler < BaseCompiler
  import static org.mirah.jvm.types.JVMTypeUtils.*

  def initialize(context:Context)
    super(context)
  end
  
  def self.initialize:void
    @@log = Logger.getLogger(AnnotationCompiler.class.getName)
  end
  
  def compile(annotations:AnnotationList, visitor:ClassVisitor):void
    compile(annotations, ClassAnnotationFactory.new(visitor))
  end
  
  def compile(annotations:AnnotationList, visitor:MethodVisitor):void
    compile(annotations, MethodAnnotationFactory.new(visitor))
  end

  def compile(annotations:AnnotationList, visitor:FieldVisitor):void
    compile(annotations, FieldAnnotationFactory.new(visitor))
  end

  def compile(annotations:AnnotationList, factory:AnnotationVisitorFactory):void
    annotations.size.times do |i|
      anno = annotations.get(i)
      
      # FIXME these classes aren't actually on the classpath, and probably shouldn't be.
      # They are SOURCE retention annotations used only by the compiler.
      next if anno.type.typeref.name.startsWith("org.mirah.jvm.")
      
      type = getInferredType(anno)
      unless isAnnotation(type)
        reportError("#{type.name} is not an annotation", anno.position)
        next
      end
      retention = type.retention
      if "SOURCE".equals(retention)
        @@log.fine("Skipping source annotation #{type.name}")
        next
      end
      @@log.fine("Compiling #{retention} annotation #{type.name}")
      visitor = factory.create(type.getAsmType.getDescriptor,
                               "RUNTIME".equals(retention))
      compileValues(anno, visitor)
      visitor.visitEnd
    end
  end
  
  def compileValues(anno:Annotation, visitor:AnnotationVisitor):void
    type = getInferredType(anno)
    anno.values_size.times do |i|
      entry = anno.values(i)
      name = Identifier(entry.key).identifier
      value = entry.value
      method = type.getMethod(name, Collections.emptyList)
      unless method
        reportError("No method #{type.name}.#{name}()", entry.key.position)
        next
      end
      value_type = method.returnType
      compileValue(visitor, name, value, value_type)
    end
  end
  
  def compileValue(visitor:AnnotationVisitor, name:String, value:Node, type:JVMType):void
    if isArray(type)
      compileArray(visitor, name, value, type.getComponentType)
    elsif isEnum(type)
      compileEnum(visitor, name, value, type)
    elsif isAnnotation(type)
      compileAnnotation(visitor, name, value, type)
    elsif isPrimitive(type)
      compilePrimitive(visitor, name, value, type)
    elsif "java.lang.String".equals(type.name)
      compileString(visitor, name, value)
    elsif "java.lang.Class".equals(type.name)
      compileClass(visitor, name, value)
    else
      reportError("Unsupported annotation value #{type.name}", value.position)
    end
  end
  
  def compileArray(visitor:AnnotationVisitor, name:String, value:Node, type:JVMType):void
    if value.kind_of?(Unquote)
      values = Unquote(value).nodes
    elsif value.kind_of?(Array)
      values = Array(value).values
    else
      reportError("Expected an array, found #{value.getClass}", value.position)
      return
    end
    child = visitor.visitArray(name)
    values.each do |n: Node|
      compileValue(child, nil, n, type)
    end
    child.visitEnd
  end
  
  def compileEnum(visitor:AnnotationVisitor, name:String, value:Node, type:JVMType):void
    unless value.kind_of?(Identifier)
      reportError("Expected an identifier, found #{value.getClass}", value.position)
      return
    end
    value_name = Identifier(value).identifier
    unless type.hasStaticField(value_name)
      reportError("Cannot find enum value #{type.name}.#{value_name}", value.position)
      return
    end
    visitor.visitEnum(name, type.getAsmType.getDescriptor, value_name)
  end
  
  def compileAnnotation(visitor:AnnotationVisitor, name:String, value:Node, type:JVMType):void
    if value.kind_of?(Unquote)
      value = Unquote(value).node
    end
    unless value.kind_of?(Annotation)
      reportError("Expected an annotation, found #{value.getClass}", value.position)
      return
    end
    subtype = getInferredType(value)
    # TODO(ribrdb): check compatibility
    child = visitor.visitAnnotation(name, subtype.getAsmType.getDescriptor)
    compileValues(Annotation(value), child)
    child.visitEnd
  end
  
  def compilePrimitive(visitor:AnnotationVisitor, name:String, value:Node, type:JVMType):void
    if value.kind_of?(Unquote)
      value = Unquote(value).node
    end
    if "boolean".equals(type.name)
      compileBool(visitor, name, value)
    elsif "float".equals(type.name) || "double".equals(type.name)
      compileFloat(visitor, name, value, type)
    else
      compileInt(visitor, name, value, type)
    end
  end
  
  def compileBool(visitor:AnnotationVisitor, name:String, value:Node):void
    unless value.kind_of?(mirah::lang::ast::Boolean)
      reportError("Expected a boolean, found #{value.getClass}", value.position)
      return
    end
    visitor.visit(name, java::lang::Boolean.valueOf(mirah::lang::ast::Boolean(value).value))
  end
  
  def compileFloat(visitor:AnnotationVisitor, name:String, value:Node, type:JVMType):void
    unless value.kind_of?(mirah::lang::ast::Float)
      reportError("Expected a float, found #{value.getClass}", value.position)
      return
    end
    double_value = mirah::lang::ast::Float(value).value
    if "float".equals(type.name)
      asm_value = java::lang::Float.valueOf(float(double_value))
    else
      asm_value = Double.valueOf(double_value)
    end
    visitor.visit(name, asm_value)
  end
  
  def compileInt(visitor:AnnotationVisitor, name:String, value:Node, type:JVMType):void
    unless value.kind_of?(Fixnum)
      reportError("Expected a #{type.name} literal, found #{value.getClass}", value.position)
      return
    end
    long_value = Fixnum(value).value
    min = Long.MIN_VALUE
    max = Long.MAX_VALUE
    if "byte".equals(type.name)
      min = long(Byte.MIN_VALUE)
      max = long(Byte.MAX_VALUE)
      asm_value = Byte.valueOf(byte(long_value))
    elsif "char".equals(type.name)
      min = long(Character.MIN_VALUE)
      max = long(Character.MAX_VALUE)
      asm_value = Character.valueOf(char(long_value))
    elsif "short".equals(type.name)
      min = long(Short.MIN_VALUE)
      max = long(Short.MAX_VALUE)
      asm_value = Short.valueOf(short(long_value))
    elsif "int".equals(type.name)
      min = long(Integer.MIN_VALUE)
      max = long(Integer.MAX_VALUE)
      asm_value = Integer.valueOf(int(long_value))
    elsif "long".equals(type.name)
      asm_value = Long.valueOf(long_value)
    else
      reportError("Unsupported primitive type #{type.name}", value.position)
      return
    end
    if long_value < min || long_value > max
      reportError("Value #{long_value} out of #{type.name} range", value.position)
      return
    end
    visitor.visit(name, asm_value)
  end
  
  def compileString(visitor:AnnotationVisitor, name:String, value:Node):void
    if value.kind_of?(Unquote)
      value = Unquote(value).node
    end
    unless value.kind_of?(SimpleString)
      reportError("Expected a string literal, found #{value.getClass}", value.position)
      return
    end
    visitor.visit(name, SimpleString(value).value)
  end
  
  def compileClass(visitor:AnnotationVisitor, name:String, value:Node):void
    unless value.kind_of?(TypeName)
      reportError("Expected a class, found #{value.getClass}", value.position)
      return
    end
    typeref = TypeName(value).typeref
    klass = context[TypeSystem].get(getScope(value), typeref).resolve
    if klass.isError
      reportError("Cannot find class #{typeref.name}", value.position)
      return
    end
    visitor.visit(name, JVMType(klass).getAsmType)
  end
end