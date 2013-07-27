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

import java.io.File

import java.util.ArrayList
import java.util.Collections
import java.util.LinkedList
import java.util.List
import java.util.logging.Logger
import java.util.logging.Level

import javax.lang.model.util.Types as JavaxTypes

import org.jruby.org.objectweb.asm.Opcodes
import org.jruby.org.objectweb.asm.Type

import mirah.lang.ast.ClassDefinition
import mirah.lang.ast.ConstructorDefinition
import mirah.lang.ast.InterfaceDeclaration
import mirah.lang.ast.Node
import mirah.lang.ast.Position
import mirah.lang.ast.Script
import mirah.lang.ast.SimpleString

import org.mirah.MirahLogFormatter
import org.mirah.builtins.Builtins

import org.mirah.typer.AssignableTypeFuture
import org.mirah.typer.BaseTypeFuture
import org.mirah.typer.CallFuture
import org.mirah.typer.DelegateFuture
import org.mirah.typer.DerivedFuture
import org.mirah.typer.ErrorType
import org.mirah.typer.GenericTypeFuture
import org.mirah.typer.MethodFuture
import org.mirah.typer.MethodType
import org.mirah.typer.NarrowingTypeFuture
import org.mirah.typer.PickFirst
import org.mirah.typer.ResolvedType
import org.mirah.typer.Scope
import org.mirah.typer.TypeFuture
import org.mirah.typer.TypeSystem
import org.mirah.typer.simple.SimpleScope
import org.mirah.util.Context

import org.mirah.jvm.mirrors.generics.TypeInvoker
import org.mirah.jvm.model.Types
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMTypeUtils
import org.mirah.jvm.types.MemberKind

class ClassPath
  attr_accessor classpath:ClassLoader, macro_classpath:ClassLoader
  attr_accessor loader:AsyncMirrorLoader
  attr_accessor bytecode_loader:MirrorLoader
  attr_accessor macro_loader:MirrorLoader
end

class MirrorTypeSystem implements TypeSystem
  def initialize(
      context:Context=nil,
      classloader:ClassLoader=MirrorTypeSystem.class.getClassLoader,
      macroloader:ClassLoader=nil)
    @primitives = {
      boolean: 'Z',
      byte: 'B',
      char: 'C',
      short: 'S',
      int: 'I',
      long: 'J',
      float: 'F',
      double: 'D',
      void: 'V',
    }

    context ||= Context.new
    @context = context
    context[MirrorTypeSystem] = self
    bytecode_loader = BytecodeMirrorLoader.new(
        context, classloader, PrimitiveLoader.new(context))
    @loader = SimpleAsyncMirrorLoader.new(context, AsyncLoaderAdapter.new(
        context, bytecode_loader))
    if macroloader
      @macroloader = BytecodeMirrorLoader.new(
          context, macroloader, bytecode_loader)
    else
      @macro_loader = bytecode_loader
    end

    context[ClassPath] = classpath = ClassPath.new
    classpath.classpath = classloader
    classpath.macro_classpath = macroloader
    classpath.loader = @loader
    classpath.bytecode_loader = bytecode_loader
    classpath.macro_loader = @macro_loader
    context[MethodLookup] = @methods = MethodLookup.new(context)
    context[JavaxTypes] = Types.new(context)

    @object_future = wrap(Type.getType('Ljava/lang/Object;'))
    @object = BaseType(@object_future.resolve)
    @main_type = TypeFuture(nil)
    @anonymousClasses = {}
    Builtins.initialize_builtins(self)
    addObjectIntrinsics
    initBoxes
  end

  attr_reader context:Context

  def self.initialize:void
    @@log = Logger.getLogger(MirrorTypeSystem.class.getName)
  end

  def parameterize(type:TypeFuture, args:List)
    last_resolved = nil
    context = @context
    invocation = nil
    future = DelegateFuture.new
    future.type = type
    type.onUpdate do |x, resolved|
      future.type = MirrorFuture.new(
          TypeInvoker.invoke(context, MirrorType(resolved), args, nil))
    end
    future
  end

  def box(type:TypeFuture)
    DerivedFuture.new(type) do |r|
      resolved = MirrorType(r)
      if JVMTypeUtils.isPrimitive(resolved)
        resolved.box
      else
        resolved
      end
    end
  end

  def getSuperClass(type)
    DerivedFuture.new(type) do |resolved|
      JVMType(resolved).superclass
    end
  end

  def getMainType(scope, script)
    @main_type ||= getMetaType(defineType(scope, script, getMainClassName(script), nil, []))
  end

  def getMainClassName(script:Script):String
    (script && script.position && script.position.source &&
         script.position.source.name &&
         MirrorTypeSystem.classnameFromFilename(script.position.source.name)) ||
        "DashE"
  end

  def addDefaultImports(scope)
    scope.import('java.lang', '*')
  end

  def getFixnumType(value)
    box = Long.valueOf(value)
    if box.intValue != value
      wrap(Type.getType("J"))
    elsif box.shortValue != value
      wrap(Type.getType("I"))
    else
      wide = wrap(Type.getType('I'))
      narrow = if box.byteValue == value
        wrap(Type.getType('B'))
      else
        wrap(Type.getType('S'))
      end
      NarrowingTypeFuture.new(nil, wide.resolve, narrow.resolve)
    end
  end

  def getCharType(value)
    wrap(Type.getType('C'))
  end

  def getFloatType(value)
    box = Double.valueOf(value)
    wide = wrap(Type.getType("D"))
    if value == box.floatValue
      narrow = wrap(Type.getType("F"))
      NarrowingTypeFuture.new(nil, wide.resolve, narrow.resolve)
    else
      wide
    end
  end

  def getVoidType
    @void ||= wrap(Type.getType("V"))
  end

  def getBlockType
    @block ||= BlockType.new
  end

  def getBooleanType
    wrap(Type.getType("Z"))
  end

  def getImplicitNilType
    @implicit_nil ||= BaseTypeFuture.new.resolved(ImplicitNil.new)
  end

  def getStringType
    wrap(Type.getType("Ljava/lang/String;"))
  end

  def getRegexType
    wrap(Type.getType("Ljava/util/regex/Pattern;"))
  end

  def getBaseExceptionType
    wrap(Type.getType("Ljava/lang/Throwable;"))
  end

  def getDefaultExceptionType
    wrap(Type.getType("Ljava/lang/Exception;"))
  end

  def getArrayLiteralType(valueType, position)
    typevar = GenericTypeFuture.new(position, @object)
    typevar.assign(box(valueType), position)
    parameterize(loadNamedType('java.util.List'), [typevar])
  end

  def getHashLiteralType(keyType, valueType, position)
    keyVar = GenericTypeFuture.new(position, @object)
    keyVar.assign(box(keyType), position)
    valueVar = GenericTypeFuture.new(position, @object)
    valueVar.assign(box(valueType), position)
    parameterize(loadNamedType("java.util.Map"), [keyVar, valueVar])
  end

  def getMethodDefType(target, name, argTypes, declaredReturnType, position)
    name = name.replaceAll('=$', '_set')
    createMember(
        MirrorType(target.resolve), name, argTypes, declaredReturnType,
        position)
  end

  def getNullType
    @nullType ||= BaseTypeFuture.new.resolved(NullType.new)
  end

  def getMethodType(call)
    future = DelegateFuture.new()
    if call.resolved_target
      if call.resolved_target.isError
        return BaseTypeFuture.new().resolved(call.resolved_target)
      end
      target = MirrorType(call.resolved_target)
      method_name = resolveMethodName(call.scope, target, call.name)
      if "<init>".equals(method_name)
        target = target.unmeta
      end
      error = JvmErrorType.new([
        ["Can't find method #{format(target, call.name, call.resolved_parameters)}",
         call.position]], Type.getType("V"), nil)
      macro_params = LinkedList.new
      nodes = call.parameterNodes
      unless nodes.nil?
        nodes.each do |n|
          type = Type.getType(n.getClass())
          macro_params.add(@macro_loader.loadMirror(type))
        end
      end
      method = @methods.findMethod(
          call.scope, target, method_name,
          call.resolved_parameters, macro_params,
          call.position, !call.explicitTarget)
      future.type = method || error
      log = @@log
      log.finer("Adding listener for #{target}.#{method_name} (#{target.getClass})")
      
      method_lookup = @methods
      target.addMethodListener(method_name) do |klass, name|
        future.type = method_lookup.findMethod(
            call.scope, target, method_name,
            call.resolved_parameters, macro_params,
            call.position, !call.explicitTarget) || error
      end
    end
    future
  end

  def getFieldType(target, name, position)
    resolved = MirrorType(target.resolve)
    klass = MirrorType(resolved.unmeta)
    member = klass.getDeclaredField(name)
    future = if member
      AsyncMember(member).asyncReturnType
    else
      createField(klass, name, resolved.isMeta, position)
    end
    AssignableTypeFuture(future)
  end

  def resolveMethodName(scope:Scope, target:ResolvedType, name:String)
    if "initialize".equals(name) && isConstructor(scope)
      "<init>"
    elsif "new".equals(name) && target.isMeta
      "<init>"
    else
      name
    end
  end

  def isConstructor(scope:Scope):boolean
    return false unless scope
    context = scope.context
    return false unless context
    return true if context.kind_of?(ConstructorDefinition)
    !context.findAncestor(ConstructorDefinition.class).nil?
  end

  def getMetaType(type:ResolvedType):ResolvedType
    if type.isError
      type
    else
      jvmType = MirrorType(type)
      if jvmType.isMeta
        jvmType
      else
        MetaType.new(jvmType)
      end
    end
  end

  def getMetaType(type:TypeFuture):TypeFuture
    types = TypeSystem(self)
    DerivedFuture.new(type) do |resolved|
      types.getMetaType(resolved)
    end
  end

  def getLocalType(scope, name, position)
    JVMScope(scope).getLocalType(name, position)
  end

  def getAbstractMethods(type)
    if type.kind_of?(MirrorType)
      @methods.gatherAbstractMethods(MirrorType(type))
    else
      Collections.emptyList
    end
  end

  def calculateName(scope:Scope, node:Node, name:String)
    if name.nil?
      outerName = scope.selfType.resolve.name
      id = 1
      if @anonymousClasses.containsKey(outerName)
        id = Integer(@anonymousClasses[outerName]).intValue + 1
      end
      @anonymousClasses[outerName] = id
      name = "#{outerName}$#{id}"
      if node
        ClassDefinition(node).name = SimpleString.new(name)
      end
      name
    elsif scope && scope.package && !scope.package.isEmpty
      "#{scope.package}.#{name}"
    else
      name
    end
  end

  def isTypeDefinition(future:TypeFuture):boolean
    return false unless future.isResolved
    resolved = future.resolve
    if resolved.kind_of?(MirahMirror)
      return true
    end
    if resolved.kind_of?(MirrorProxy)
      MirrorProxy(resolved).target.kind_of?(MirahMirror)
    end
  end

  def defineType(scope, node, name, superclass, interfaces)
    position = node ? node.position : nil
    fullname = calculateName(scope, node, name)
    type = Type.getObjectType(fullname.replace(?., ?/))
    existing = wrap(type)      
    if isTypeDefinition(existing)
      existing
    else
      superclass ||= @object_future
      interfaceArray = TypeFuture[interfaces.size]
      interfaces.toArray(interfaceArray)
      flags = Opcodes.ACC_PUBLIC
      if node.kind_of?(InterfaceDeclaration)
        flags |= Opcodes.ACC_INTERFACE | Opcodes.ACC_ABSTRACT
      end
      mirror = MirahMirror.new(@context, type, flags,
                               superclass, interfaceArray)
      addClassIntrinsic(mirror)
      future = MirrorFuture.new(mirror, position)
      @loader.defineMirror(type, future)
      future
    end
  end

  def get(scope, typeref)
    name = resolveName(scope, typeref.name)
    type = if scope.nil?
      loadNamedType(name)
    else
      loadWithScope(scope, name, typeref.position)
    end
    if typeref.isArray
      getArrayType(type)
    else
      type
    end
  end

  def resolveName(scope:Scope, name:String):String
    if scope
      String(scope.imports[name]) || name
    else
      name
    end
  end

  def loadNamedType(name:String)
    desc = @primitives[name]
    type = if desc
      Type.getType(String(desc))
    else
      Type.getObjectType(name.replace(?., ?/))
    end
    @loader.loadMirrorAsync(type)
  end

  def loadWithScope(scope:Scope, name:String, position:Position):TypeFuture
    packageName = scope.package
    default_package = (packageName.nil? || packageName.isEmpty)
    types = LinkedList.new
    scope.search_packages.each do |p|
      fullname = "#{p}.#{name}"
      types.add(loadNamedType(fullname))
      types.add(nil)
    end
    types.addFirst(nil)
    if default_package
      types.addFirst(loadNamedType(name))
    else
      types.addFirst(loadNamedType("#{packageName}.#{name}"))
      types.addLast(loadNamedType(name))
      types.addLast(nil)
    end
    future = PickFirst.new(types, nil)
    future.position = position
    future.error_message = "Cannot find class #{name}"
    future
  end

  def getResolvedArrayType(componentType:ResolvedType):ResolvedType
    ArrayType.new(@context, cast(componentType))
  end

  def getArrayType(componentType:ResolvedType):ResolvedType
    getResolvedArrayType(componentType)
  end

  def getArrayType(componentType:TypeFuture):TypeFuture
    types = self
    DerivedFuture.new(componentType) do |resolved|
      types.getResolvedArrayType(resolved)
    end
  end

  def addMacro(klass:ResolvedType, macro_impl:Class)
    type = BaseType(klass).unmeta
    member = MacroMember.create(macro_impl, type, @macro_loader)
    type.add(member)
    @@log.fine("Added macro #{member}")
  end

  def extendClass(classname:String, extensions:Class)
    type = BaseType(loadNamedType(classname).resolve)
    BytecodeMirrorLoader.extendClass(type, extensions, @macro_loader)
  end

  def addClassIntrinsic(type:BaseType)
    future = BaseTypeFuture.new.resolved(type)
    klass = loadNamedType('java.lang.Class')
    generic_class = JVMType(parameterize(klass, [future]).resolve)
    type.add(Member.new(
        Opcodes.ACC_PUBLIC | Opcodes.ACC_STATIC, type, 'class', [],
        generic_class, MemberKind.CLASS_LITERAL))
  end

  def addObjectIntrinsics
    BytecodeMirrorLoader.extendClass(
        @object, MirrorObjectExtensions.class, @macro_loader)
    bool = JVMType(getBooleanType.resolve)
    @object.add(Member.new(
        Opcodes.ACC_PUBLIC, @object, 'nil?', [],
        bool, MemberKind.IS_NULL))
    object_meta = getMetaType(@object_future).resolve
    @object.add(Member.new(
        Opcodes.ACC_PUBLIC, @object, 'kind_of?', [object_meta],
        bool, MemberKind.INSTANCEOF))
    @object.add(Member.new(
        Opcodes.ACC_PUBLIC, @object, '==', [@object],
        bool, MemberKind.COMPARISON_OP))
    @object.add(Member.new(
        Opcodes.ACC_PUBLIC, @object, '!=', [@object],
        bool, MemberKind.COMPARISON_OP))
  end

  def wrap(type:Type):TypeFuture
    @loader.loadMirrorAsync(type)
  end

  def cast(type:ResolvedType)
    if type.kind_of?(MirrorType)
      MirrorType(type)
    else
      JvmErrorType.new(
          ErrorType(type).message, Type.getType("Ljava/lang/Object;"), @object)
    end
  end

  def createMember(target:MirrorType, name:String, arguments:List,
                   returnType:TypeFuture, position:Position):MethodFuture
    returnFuture = AssignableTypeFuture.new(position)

    flags = Opcodes.ACC_PUBLIC
    kind = MemberKind.METHOD
    isMeta = target.isMeta
    if isMeta
      target = MirrorType(MetaType(target).unmeta)
      flags |= Opcodes.ACC_STATIC
      kind = MemberKind.STATIC_METHOD
    end
    if target.isInterface
      flags |= Opcodes.ACC_ABSTRACT
    end
    if "initialize".equals(name)
      if isMeta
        name = "<clinit>"
        kind = MemberKind.STATIC_INITIALIZER
      else
        name = "<init>"
        kind = MemberKind.CONSTRUCTOR
      end
      returnType = getVoidType
    end
    member = AsyncMember.new(flags, target, name, arguments, returnFuture, kind)
    overriden_return = inferOverride(target, name, arguments)
    returnType ||= overriden_return

    returnFuture.error_message =
        "Cannot determine return type for method #{member}"
    returnFuture.declare(returnType, position) if returnType

    log = @@log
    me = self
    returnFuture.onUpdate do |x, resolved|
      type = isMeta ? "static " : ""
      formatted = me.format(target, name, arguments)
      log.fine("Learned #{type}#{formatted}:#{resolved}")
    end

    target.add(member)
    MethodFuture.new(name, member.argumentTypes, returnFuture, false, position)
  end

  def inferOverride(target:MirrorType, name:String, arguments:List):TypeFuture
    override = Member(@methods.findOverride(target, name, arguments.size))
    if override
      arguments.size.times do |i|
        arg = AssignableTypeFuture(arguments.get(i))
        unless arg.hasDeclaration
          arg.declare(override.asyncArgument(i), nil)
        end
      end
      override.asyncReturnType
    end
  end

  def createField(target:MirrorType, name:String,
                  isStatic:boolean, position:Position):TypeFuture
    flags = Opcodes.ACC_PRIVATE
    if isStatic
      kind = MemberKind.STATIC_FIELD_ACCESS
      flags |= Opcodes.ACC_STATIC
      access = "static"
    else
      kind = MemberKind.FIELD_ACCESS
      access = "instance"
    end
    future = AssignableTypeFuture.new(position)
    log = @@log
    future.onUpdate do |x, resolved|
      log.fine("Learned #{access} field #{target}.#{name} = #{resolved}")
    end
    member = AsyncMember.new(
        flags, target, name, [], future, kind)
    target.declareField(member)
    future
  end

  def initBoxes
    setBox('Z', 'Boolean')
    setBox('B', 'Byte')
    setBox('C', 'Character')
    setBox('S', 'Short')
    setBox('I', 'Integer')
    setBox('J', 'Long')
    setBox('F', 'Float')
    setBox('D', 'Double')
  end

  def setBox(a:String, b:String)
    primitive = BaseType(wrap(Type.getType(a)).resolve)
    boxed = BaseType(loadNamedType("java.lang.#{b}").resolve)
    primitive.boxed = boxed
    boxed.unboxed = primitive
  end

  def format(target:ResolvedType, name:String, args:List)
    sb = StringBuilder.new
    sb.append(target)
    sb.append('.')
    sb.append(name)
    sb.append('(')
    i = 0
    args.each do |arg|
      if arg.kind_of?(TypeFuture)
        future = TypeFuture(arg)
        if future.isResolved
          arg = future.resolve
        end
      end
      sb.append(", ") if i > 0
      sb.append(arg)
      i += 1
    end
    sb.append(')')
    sb.toString
  end

  def self.classnameFromFilename(name:String)
    basename = File.new(name).getName()
    if basename.endsWith(".mirah")
      basename = basename.substring(0, basename.length - 6)
    end
    sb = StringBuilder.new
    basename.split('[-_.]+').each do |s|
      if s.length > 0
        sb.append(s.substring(0, 1).toUpperCase)
      end
      if s.length > 1
        sb.append(s.substring(1, s.length))
      end
    end
    sb.toString
  end

  def self.main(args:String[]):void
    logger = MirahLogFormatter.new(true).install
    logger.setLevel(Level.ALL)
    types = MirrorTypeSystem.new
    a = types.getStringType.resolve
    b = types.getRegexType.resolve
    c = a.widen(b)
    puts c
  end
end

class FakeMember < Member
  def self.create(types:MirrorTypeSystem, description:String, flags:int=-1)
    m = /^(@)?([^.]+)\.(.+)$/.matcher(description)
    unless m.matches
      raise IllegalArgumentException, "Invalid method specification #{description}"
    end
    abstract = !m.group(1).nil?
    klass = wrap(types, Type.getType(m.group(2)))
    method = Type.getType(m.group(3))
    returnType = wrap(types, method.getReturnType)
    args = LinkedList.new
    method.getArgumentTypes.each do |arg|
      args.add(wrap(types, arg))
    end
    flags = Opcodes.ACC_PUBLIC if flags == -1
    flags |= Opcodes.ACC_ABSTRACT if abstract
    FakeMember.new(description, flags, klass, returnType, args)
  end

  def self.wrap(types:MirrorTypeSystem, type:Type)
    JVMType(types.wrap(type).resolve)
  end

  def initialize(description:String, flags:int,
                 klass:JVMType, returnType:JVMType, args:List)
    super(flags, klass, 'foobar', args, returnType, MemberKind.METHOD)
    @description = description
  end

  def toString
    @description
  end
end