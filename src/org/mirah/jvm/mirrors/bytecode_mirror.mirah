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

package org.mirah.jvm.mirrors

import java.util.ArrayList
import java.util.Collections
import java.util.LinkedHashMap
import java.util.LinkedList
import java.util.List
import org.objectweb.asm.Opcodes
import org.objectweb.asm.Type
import org.objectweb.asm.tree.AnnotationNode
import org.objectweb.asm.tree.ClassNode
import org.objectweb.asm.tree.FieldNode
import org.objectweb.asm.tree.InnerClassNode
import org.objectweb.asm.tree.MethodNode
import org.mirah.jvm.mirrors.generics.GenericsCapableSignatureReader
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.types.JVMField
import org.mirah.jvm.types.MemberKind
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.MethodType
import org.mirah.typer.TypeFuture
import org.mirah.util.Context
import mirah.lang.ast.TypeRefImpl


interface MirrorLoader
  def loadMirror(type:Type):MirrorType; end
end

interface AsyncMirrorLoader
  # The future must resolve to a MirrorType.
  def loadMirrorAsync(type:Type):TypeFuture; end
end

class BytecodeMirror < AsyncMirror implements DeclaredMirrorType
  def initialize(context:Context, klass:ClassNode, loader:MirrorLoader)
    super(context, Type.getObjectType(klass.name), klass.access)
    @context = context
    @loader = loader
    @fields = klass.fields
    @methods = klass.methods
    @superName = klass.superName
    @signature = klass.signature
    @interface_names = klass.interfaces
    @annotations = klass.visibleAnnotations
    @innerClassNodes = klass.innerClasses
    @typeParams = LinkedHashMap.new
    @linked = false
  end

  def self.lookupType(loader:MirrorLoader, internalName:String)
    if internalName
      return loader.loadMirror(Type.getType("L#{internalName};"))
    end
    nil
  end

  def ensure_linked
    if !@linked
      @linked = true
      link_internal
    end
  end

  $org.mirah.jvm.types.Modifiers[access: 'PROTECTED']
  def link_internal:void
    types = @context[MirrorTypeSystem]
    if @signature
      signature_reader = GenericsCapableSignatureReader.new(@context)
      signature_reader.read(@signature)
      setSupertypes(signature_reader.superclass, signature_reader.interfaces)
      signature_reader.getFormalTypeParameters.each do |var|
        @typeParams[var.toString] = BaseTypeFuture.new.resolved(MirrorType(var))
      end
    else
      superclass = @superName ? types.wrap(Type.getType("L#{@superName};")) : nil
      interfaces = TypeFuture[@interface_names ? @interface_names.size : 0]
      if @interface_names
        it = @interface_names.iterator
        interfaces.length.times do |i|
          interfaces[i] = types.wrap(Type.getType("L#{it.next};"))
        end
      end
      setSupertypes(superclass, interfaces)
    end
    types.addClassIntrinsic(self)
  end

  def lookupType(internalName:String):MirrorType
    return BytecodeMirror.lookupType(@loader, internalName)
  end
  def lookup(type:Type):MirrorType
    @loader.loadMirror(type)
  end

  def addMethod(method:MethodNode):void
    kind = if "<clinit>".equals(method.name)
      MemberKind.STATIC_INITIALIZER
    elsif "<init>".equals(method.name)
      MemberKind.CONSTRUCTOR
    elsif 0 != (method.access & Opcodes.ACC_STATIC)
      MemberKind.STATIC_METHOD
    else
      MemberKind.METHOD
    end
    method_type = Type.getType(method.desc)
    argument_mirrors = LinkedList.new
    argument_types = method_type.getArgumentTypes
    argument_types.each do |t|
      argument_mirrors.add(lookup(t))
    end
    member = Member.new(
        method.access, self, method.name, argument_mirrors,
        lookup(method_type.getReturnType), kind)
    member.signature = method.signature
    add(member)
  end

  def addInnerClass(node:InnerClassNode):void
    flags = node.access | Opcodes.ACC_STATIC
    name = node.innerName
    args = Collections.emptyList
    result = MetaType.new(lookupType(node.name))
    kind = MemberKind.CLASS_LITERAL
    add(Member.new(flags, self, name, args, result, kind))
  end

  def retention
    # CLASS is the default retention policy http://docs.oracle.com/javase/7/docs/api/java/lang/annotation/RetentionPolicy.html#CLASS
    return "CLASS" unless @annotations

    @annotations.each do |anno: AnnotationNode|
      if "Ljava/lang/annotation/Retention;".equals(anno.desc)
        # anno.values should be
        # ["value", ["Ljava/lang/annotation/RetentionPolicy;", policy]]
        value = String[].cast(anno.values.get(1))
        return value[1]
      end
    end
  end

  attr_reader signature:String

  def load_methods:boolean
    @methods.each do |m: MethodNode|
      addMethod(m)
    end if @methods
    @methods = nil
    @innerClassNodes.each do |n: InnerClassNode|
      addInnerClass(n)
    end
    true
  end

  def getDeclaredFields:JVMField[]
    @field_mirrors ||= begin
      mirrors = JVMField[@fields.size]
      it = @fields.iterator
      @fields.size.times do |i|
        field = FieldNode(it.next)
        type = lookup(Type.getType(field.desc))
        kind = if Opcodes.ACC_STATIC == (field.access & Opcodes.ACC_STATIC)
                 MemberKind.STATIC_FIELD_ACCESS
               else
                 MemberKind.FIELD_ACCESS
               end
        member = Member.new(field.access, self, field.name, [], type, kind)
        member.signature = field.signature
        mirrors[i] = member
      end
      @fields = nil
      mirrors
    end
  end

  def getDeclaredField(name:String)
    getDeclaredFields.each do |field|
      if field.name.equals(name)
        return field
      end
    end
    nil
  end

  def getTypeVariableMap
    @typeParams
  end

  # This should only used by StringCompiler to lookup
  # StringBuilder.append(). This really should happen
  # during type inference :-(
  def getMethod(name:String, params:List):JVMMethod
    @methods_loaded ||= load_methods
    members = getMembers(name)
    if members
      members.each do |member: Member|
        if member.argumentTypes.equals(params)
          return member
        end
      end
    end
    t = @context[MethodLookup].findMethod(nil, self, name, params, nil, nil, false)
    if t
      return ResolvedCall(MethodType(t.resolve).returnType).member
    end
  end
end
