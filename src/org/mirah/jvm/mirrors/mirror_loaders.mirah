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

package org.mirah.jvm.mirrors

import java.util.Collections
import java.util.List
import org.mirah.util.Logger
import java.util.regex.Pattern
import java.io.InputStream

import org.objectweb.asm.Opcodes
import org.objectweb.asm.Type
import org.objectweb.asm.ClassReader
import org.objectweb.asm.tree.AnnotationNode
import org.objectweb.asm.tree.ClassNode

import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.DelegateFuture
import org.mirah.typer.DerivedFuture
import org.mirah.typer.ErrorMessage
import org.mirah.typer.TypeFuture

import org.mirah.util.Context

class ResourceLoader
  def initialize(parent:ResourceLoader=nil)
    @parent = parent
  end
  def findResource(name:String):InputStream; nil; end
  def getResourceAsStream(name:String):InputStream
    if @parent
      @parent.getResourceAsStream(name) || findResource(name)
    else
      findResource(name)
    end
  end
end

class ClassResourceLoader < ResourceLoader
  def initialize(klass:Class, parent:ResourceLoader=nil)
    super(parent)
    @klass = klass
  end

  def findResource(name)
    name = "/#{name}" unless name.startsWith("/")
    @klass.getResourceAsStream(name)
  end
end

class ClassLoaderResourceLoader < ResourceLoader
  def initialize(loader:ClassLoader, parent:ResourceLoader=nil)
    super(parent)
    @loader = loader
  end

  def findResource(name)
    @loader.getResourceAsStream(name)
  end
end

class FilteredResources < ResourceLoader
  def initialize(source:ResourceLoader, filter:Pattern, parent:ResourceLoader=nil)
    super(parent)
    @source = source
    @filter = filter
  end
  def findResource(name)
    if @filter.matcher(name).lookingAt
      @source.getResourceAsStream(name)
    end
  end
end

class NegativeFilteredResources < ResourceLoader
  def initialize(source:ResourceLoader, filter:Pattern, parent:ResourceLoader=nil)
    super(parent)
    @source = source
    @filter = filter
  end
  def findResource(name)
    unless @filter.matcher(name).lookingAt
      @source.getResourceAsStream(name)
    end
  end
end

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
    if mirror
      @mirrors[type] = mirror
      if mirror.kind_of?(DeclaredMirrorType)
        DeclaredMirrorType(mirror).ensure_linked
      end
    end
    return mirror
  end

  # Just delegates to the parent loader.
  def findMirror(type:Type):MirrorType
    @parent.loadMirror(type) if @parent
  end
end

class PrimitiveLoader < SimpleMirrorLoader
  def initialize(context:Context, parent:MirrorLoader=nil)
    super(parent)
    @context = context
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
    @mirrors[type] = Number.new(@context, type, supertype, self)
  end

  def defineBoolean
    type = Type.getType('Z')
    @mirrors[type] = BooleanType.new(@context, self)
  end

  def findMirror(type:Type)
    super || MirrorType(@mirrors[type])
  end
end

class SimpleAsyncMirrorLoader implements AsyncMirrorLoader
  def initialize(context:Context, parent:AsyncMirrorLoader=nil)
    @context = context
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
    JvmErrorType.new([ErrorMessage.new("Cannot find class #{type.getClassName}")], type, object)
  end

  def findArrayMirrorAsync(type:Type):TypeFuture
    context = @context
    DerivedFuture.new(loadMirrorAsync(type)) do |resolved|
      ArrayType.new(context, MirrorType(resolved))
    end
  end

  def defineMirror(type:Type, mirror:TypeFuture):TypeFuture
    delegate = DelegateFuture(@futures[type] ||= DelegateFuture.new)
    delegate.type = mirror
    delegate
  end
end

class AsyncLoaderAdapter < SimpleAsyncMirrorLoader
  def initialize(context:Context, parent:MirrorLoader)
    super(context, nil)
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
    JvmErrorType.new([ErrorMessage.new("Cannot find class #{type.getClassName}")], type, object)
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
                 resourceLoader:ResourceLoader,
                 parent:MirrorLoader=nil)
    super(parent)
    @context = context
    @loader = resourceLoader
    @ancestorLoader = OrErrorLoader.new(self)
    @parent=parent
  end

  def findMirror(type)
    super || begin
      @@log.fine "findMirror #{type}"
      if type.getSort == Type.ARRAY
        return findArrayMirror(Type.getType(type.getDescriptor.substring(1)))
      end
      classfile = type.getInternalName + ".class"
      while true
        bytecode = @loader.getResourceAsStream(classfile)
        if bytecode
          node = BytecodeMirrorLoader.class_node_for(bytecode)
          if "#{node.name}.class".equals(classfile)
            @@log.fine("Found #{classfile}")
            mirror = BytecodeMirror.new(@context, node, @ancestorLoader)
            macro_loader = @context[ClassLoader]
            BytecodeMirrorLoader.findOldAndNewStyleMacros(macro_loader, mirror, node, classfile)

            return mirror
          end
        end
        lastSlash = classfile.lastIndexOf(?/)
        break if lastSlash == -1
        classfile = classfile.substring(0, lastSlash) + "$" + classfile.substring(lastSlash + 1)
      end
      @@log.fine("Cannot find #{classfile}")
      nil
    end
  end

  def findArrayMirror(type:Type):MirrorType
    component = loadMirror(type)
    if component
      ArrayType.new(@context, component)
    end
  end

  def self.addMacro(type:BaseType, name:String)
    member = internalAddMacro type, name
    @@log.fine("Loaded macro #{member}")
  end

  def self.internalAddMacro(type: BaseType, name: String)
    classloader = type.context[ClassLoader]
    klass = if classloader
      classloader.loadClass(name)
    else
      Class.forName(name)
    end
    member = MacroMember.create(klass, type, type.context)
    type.add(member)
    member
  end

  def self.extendClass(type: BaseType, extensions: Class)
    @@log.fine "extend class #{type} with #{extensions}"
    mirah_classloader = extensions.getClassLoader

    path = "#{extensions.getName.replace(?., ?/)}.class"
    node = class_node_for(mirah_classloader.getResourceAsStream(path))
    
    findOldAndNewStyleMacros(mirah_classloader, type, node, path)
  end

  def self.findOldAndNewStyleMacros(macro_loader: ClassLoader,
                      type: BaseType,
                      initialByteCode: ClassNode,
                      classfile: String): void
    return unless initialByteCode # class doesn't exist then
    unless macro_loader # there's no macro loader, so we're in a badly constructed something
      return
    end

    @@log.finer "  attempting old style lookup on: #{classfile}"
    BytecodeMirrorLoader.findAndAddMacros(initialByteCode, type)

    # instead of looking on node, find node$Extensions, and load from there
    new_style_extension_classname = classfile.replace(".class", "$Extensions.class")
    @@log.finer "  attempting new style: #{new_style_extension_classname}"
    
    bytecode = macro_loader.getResourceAsStream(new_style_extension_classname)
    if bytecode
      @@log.fine "  macro class found on classpath"
      node = BytecodeMirrorLoader.class_node_for(bytecode)
      BytecodeMirrorLoader.findAndAddMacros(node, type)
    else
      @@log.finer "  macro class not found on classpath"
    end
        
  end

  def self.findAndAddMacros(node: ClassNode, type: BaseType): void
    macros = findMacros(node)
    @@log.fine "  found #{macros.size} macros. Loading"
    macros.each do |name|
      member = internalAddMacro(type, String(name))
      @@log.fine "    #{member}"
    end
  end

  def self.findMacros(klass:ClassNode)
    klass.invisibleAnnotations.each do |a|
      annotation = AnnotationNode(a)
      if "Lorg/mirah/macros/anno/Extensions;".equals(annotation.desc)
        return List(annotation.values.get(1))
      end
    end if klass.invisibleAnnotations
    Collections.emptyList
  end

  def self.class_node_for(bytecode: InputStream)
    node = ClassNode.new
    reader = ClassReader.new(bytecode)
    reader.accept(node, ClassReader.SKIP_CODE)
    node
  end

end