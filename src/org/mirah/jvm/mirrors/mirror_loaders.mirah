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

import java.util.Collections
import java.util.List
import java.util.logging.Logger

import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.Type
import org.jruby.org.objectweb.asm.ClassReader
import org.jruby.org.objectweb.asm.tree.AnnotationNode
import org.jruby.org.objectweb.asm.tree.ClassNode

import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.DelegateFuture
import org.mirah.typer.DerivedFuture
import org.mirah.typer.TypeFuture

import org.mirah.util.Context

class SimpleMirrorLoader implements MirrorLoader
  def initialize(parent:MirrorLoader=nil)
    @parent = parent
    @mirrors = {}
  end

  attr_reader parent:MirrorLoader

  # 1) Returns the previously found mirror if one exists for this type.
  # 2) Otherwise calls findMirror() and returns the result.
  # Subclasses should usually override findMirror instead of this method.
  def loadMirror(type:Type):MirrorType
    existing = MirrorType(@mirrors[type])
    return existing if existing
    mirror = findMirror(type)
    @mirrors[type] = mirror if mirror
    return mirror
  end

  # Just delegates to the parent loader.
  def findMirror(type:Type):MirrorType
    @parent.loadMirror(type) if @parent
  end
end

class PrimitiveLoader < SimpleMirrorLoader
  def initialize(parent:MirrorLoader=nil)
    super(parent)
    @mirrors = {}
    defineVoidType
    defineBoolean
    d = defineNumber("D", nil)
    f = defineNumber("F", d)
    l = defineNumber("J", f)
    i = defineNumber("I", l)
    defineNumber("C", i)
    s = defineNumber("S", i)
    defineNumber("B", s)
  end

  def defineVoidType
    @mirrors[Type.getType("V")] = VoidType.new
  end

  def defineNumber(desc:String, supertype:MirrorType)
    type = Type.getType(desc)
    @mirrors[type] = Number.new(type, supertype, self)
  end

  def defineBoolean
    type = Type.getType('Z')
    @mirrors[type] = BooleanType.new(self)
  end

  def findMirror(type:Type)
    super || MirrorType(@mirrors[type])
  end
end

class SimpleAsyncMirrorLoader implements AsyncMirrorLoader
  def initialize(parent:AsyncMirrorLoader=nil)
    @parent = parent
    @futures = {}
  end

  attr_reader parent:AsyncMirrorLoader

  # Note that the order here is different from SimpleMirrorLoader:
  # We delegate to the parent after checking if we know about the type.
  def loadMirrorAsync(type:Type):TypeFuture
    TypeFuture(@futures[type] ||= findMirrorAsync(type))
  end

  def findMirrorAsync(type:Type):TypeFuture
    if type.getSort == Type.ARRAY
      return findArrayMirrorAsync(Type.getType(type.getDescriptor.substring(1)))
    end
    future = DelegateFuture.new
    future.type = if parent
      @parent.loadMirrorAsync(type)
    else
      makeError(type)
    end
    future
  end

  def makeError(type:Type)
    object =  if type.getDescriptor.equals("Ljava/lang/Object;")
      nil
    else
      MirrorType(loadMirrorAsync(
        Type.getType("Ljava/lang/Object;")).resolve) rescue nil
    end
    JvmErrorType.new([["Cannot find class #{type.getClassName}"]], type, object)
  end

  def findArrayMirrorAsync(type:Type):TypeFuture
    loader = self
    DerivedFuture.new(loadMirrorAsync(type)) do |resolved|
      ArrayType.new(MirrorType(resolved), loader)
    end
  end

  def defineMirror(type:Type, mirror:TypeFuture):TypeFuture
    delegate = DelegateFuture(@futures[type] ||= DelegateFuture.new)
    delegate.type = mirror
    delegate
  end
end

class AsyncLoaderAdapter < SimpleAsyncMirrorLoader
  def initialize(parent:MirrorLoader)
    super(nil)
    @parent = parent
  end
  
  def findMirrorAsync(type:Type):TypeFuture
    mirror = @parent.loadMirror(type)
    if mirror
      future = BaseTypeFuture.new
      future.resolved(mirror)
      defineMirror(type, future)
    else
      super
    end
  end
end

class OrErrorLoader < SimpleMirrorLoader
  def initialize(parent:MirrorLoader)
    super(parent)
  end
  def findMirror(type)
    super || makeError(type)
  end

  def makeError(type:Type)
    object = if type.getDescriptor.equals("Ljava/lang/Object;")
      nil
    else
      loadMirror(Type.getType("Ljava/lang/Object;"))
    end
    JvmErrorType.new([["Cannot find class #{type.getClassName}"]], type, object)
  end
end

class SyncLoaderAdapter implements MirrorLoader
  def initialize(loader:AsyncMirrorLoader)
    @loader = loader
  end
  def loadMirror(type:Type):MirrorType
    resolved = @loader.loadMirrorAsync(type).resolve
    unless resolved.isError
      MirrorType(resolved)
    end
  end
end

class BytecodeMirrorLoader < SimpleMirrorLoader
  def self.initialize:void
    @@log = Logger.getLogger(BytecodeMirrorLoader.class.getName)
  end

  def initialize(context:Context,
                 resourceLoader:ClassLoader,
                 parent:MirrorLoader=nil)
    super(parent)
    @context = context
    @loader = resourceLoader
    @ancestorLoader = OrErrorLoader.new(self)
  end

  def findMirror(type)
    super || begin
      if type.getSort == Type.ARRAY
        return findArrayMirror(Type.getType(type.getDescriptor.substring(1)))
      end
      classfile = type.getInternalName + ".class"
      while true
        bytecode = @loader.getResourceAsStream(classfile)
        if bytecode
          node = ClassNode.new
          reader = ClassReader.new(bytecode)
          reader.accept(node, ClassReader.SKIP_CODE)
          if "#{node.name}.class".equals(classfile)
            @@log.fine("Found #{classfile}")
            mirror = BytecodeMirror.new(node, @ancestorLoader)
            BytecodeMirrorLoader.findMacros(node).each do |name|
              BytecodeMirrorLoader.addMacro(mirror, String(name), @ancestorLoader)
            end
            return mirror
          end
        end
        lastSlash = classfile.lastIndexOf(?/)
        break if lastSlash == -1
        classfile = classfile.substring(0, lastSlash) + "$" + classfile.substring(lastSlash + 1)
      end
      @@log.finer("Cannot find #{classfile}")
      nil
    end
  end

  def findArrayMirror(type:Type):MirrorType
    component = loadMirror(type)
    if component
      ArrayType.new(@context, component)
    end
  end

  def self.addMacro(type:BaseType, name:String, loader:MirrorLoader)
    klass = Class.forName(name)
    member = MacroMember.create(klass, type, loader)
    type.add(member)
    @@log.fine("Loaded macro #{member}")
  end

  def self.extendClass(type:BaseType, extensions:Class, loader:MirrorLoader)
    path = "/#{extensions.getName.replace(?., ?/)}.class"
    stream = extensions.getResourceAsStream(path)
    node = ClassNode.new
    ClassReader.new(stream).accept(node, ClassReader.SKIP_CODE)
    macros = findMacros(node)
    macros.each do |name|
      addMacro(type, String(name), loader)
    end
  end

  def self.findMacros(klass:ClassNode)
    klass.invisibleAnnotations.each do |a|
      annotation = AnnotationNode(a)
      if "Lorg/mirah/macros/anno/Extensions;".equals(annotation.desc)
        return List(annotation.values.get(1))
      end
    end if klass.invisibleAnnotations
    return Collections.emptyList
  end
end

class SelfMirrorLoader < SimpleMirrorLoader
  def initialize(mirror:MirrorType)
    @mirror = mirror
  end

  def findMirror(type)
    if type.equals(@mirror.getAsmType)
      return @mirror
    end
    super
  end
end