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

import org.objectweb.asm.Opcodes
import org.objectweb.asm.Type

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
import org.mirah.typer.UnreachableType
import org.mirah.typer.simple.SimpleScope
import org.mirah.util.Context

import org.mirah.jvm.mirrors.generics.TypeInvoker
import org.mirah.jvm.model.Types
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMTypeUtils
import org.mirah.jvm.types.MemberKind

class MirrorTypeSystem implements TypeSystem
  def initialize(
      context:Context=nil,
      classloader:ResourceLoader=nil)
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
    classloader ||= ClassResourceLoader.new(MirrorTypeSystem.class)
    bytecode_loader = BytecodeMirrorLoader.new(
        context, classloader, PrimitiveLoader.new(context))
    @loader = SimpleAsyncMirrorLoader.new(context, AsyncLoaderAdapter.new(
        context, bytecode_loader))

    context[MethodLookup] = @methods = MethodLookup.new(context)
    context[JavaxTypes] = Types.new(context)

    @object_future = wrap(Type.getType('Ljava/lang/Object;'))
    @object = BaseType(@object_future.resolve)
    @anonymousClasses = {}
    @unpinned_field_futures = {}
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
      unless r.kind_of?(MirrorType)
        r
      else
        resolved = MirrorType(r)
        if JVMTypeUtils.isPrimitive(resolved)
          resolved.box
        else
          resolved
        end
      end
    end
  end

  def getSuperClass(type)
    DerivedFuture.new(type) do |resolved|
      JVMType(resolved).superclass
    end
  end

  def getMainType(scope, script)
    getMetaType(defineType(scope, script, MirrorTypeSystem.getMainClassName(script), nil, []))
  end

  def self.getMainClassName(script:Script):String
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
        MirrorType(target.peekInferredType), name, argTypes, declaredReturnType,
        position)
  end

  def getNullType
    @nullType ||= BaseTypeFuture.new.resolved(NullType.new)
  end

  def getMethodType(call)
    future = DelegateFuture.new()
    if call.resolved_target
      if call.resolved_target.isError || call.resolved_target.kind_of?(UnreachableType)
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
          typename = n.getClass.getName
          macro_params.add(loadMacroType(typename))
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
      listener = lambda(MethodListener) do |klass, name|
        future.type = method_lookup.findMethod(
            call.scope, target, method_name,
            call.resolved_parameters, macro_params,
            call.position, !call.explicitTarget) || error
      end
      target.addMethodListener(method_name, listener)
      unless call.explicitTarget || call.scope.nil?
        MirrorScope(call.scope).staticImports.each do |f:TypeFuture|
          f.onUpdate do |x, resolved|
            if resolved.kind_of?(MirrorType)
              MirrorType(resolved).addMethodListener(method_name, listener)
              if resolved.kind_of?(MirrorProxy)
                if BaseType(MirrorProxy(resolved).target).hasMember(method_name) # if the method was already created, then
                  listener.methodChanged(MirrorType(resolved),method_name)       #   fire the listener right away
                end
              end
            end
          end
        end
      end
    end
    future
  end

  def getFieldType(target, name, position)
    resolved = MirrorType(target.peekInferredType)
    klass = MirrorType(resolved.unmeta)
    member = klass.getDeclaredField(name)
    if member
      @@log.finest "found declared field future for target: #{target} name: #{name}"
      return AssignableTypeFuture(AsyncMember(member).asyncReturnType)
    end

    undeclared_future = @unpinned_field_futures[unpinned_key(klass, name)]
    if undeclared_future
      @@log.finest "found undeclared field future for target: #{klass} name: #{name}"
      return AssignableTypeFuture(undeclared_future)
    end

    @@log.finest "creating undeclared field's future target: #{target} name: #{name}"
    future = AssignableTypeFuture.new(position)
    @unpinned_field_futures[unpinned_key(klass, name)] = future
    AssignableTypeFuture(future)
  end

  def getFieldTypeOrDeclare(target, name, position)
    resolved = MirrorType(target.peekInferredType)
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
      if resolved.isError
        resolved
      else
        MirrorProxy.create(MirrorType(types.getMetaType(resolved)))
      end
    end
  end

  def getLocalType(scope, name, position)
    MirrorScope(scope).getLocalType(name, position)
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
    elsif scope && scope.package && !scope.package.isEmpty && !name.contains(".")
      "#{scope.package}.#{name}"
    else
      name
    end
  end

  def findTypeDefinition(future:TypeFuture):MirahMirror
    return nil unless future.isResolved
    resolved = future.resolve
    while resolved.kind_of?(MirrorProxy)
      resolved = MirrorProxy(resolved).target
    end
    if resolved.kind_of?(MirahMirror)
      MirahMirror(resolved)
    else
      nil
    end
  end

  def defineType(scope:Scope, node:Node, name:String, superclass:TypeFuture, interfaces:List)
    type_future = createType(scope,node,name,superclass,interfaces)
    publishType(type_future)
    type_future
  end

  def createType(scope:Scope, node:Node, name:String, superclass:TypeFuture, interfaces:List)
    position = node ? node.position : nil
    fullname = calculateName(scope, node, name)
    type = Type.getObjectType(fullname.replace(?., ?/))
    existing_future = DelegateFuture(wrap(type)).type
    existing_type = findTypeDefinition(existing_future)
    if existing_type
      if superclass.nil? && (interfaces.nil? || interfaces.size == 0)
        return existing_future
      end
    end

    superclass ||= @object_future
    interfaceArray = TypeFuture[interfaces.size]
    interfaces.toArray(interfaceArray)
    flags = Opcodes.ACC_PUBLIC
    if node.kind_of?(InterfaceDeclaration)
      flags |= Opcodes.ACC_INTERFACE | Opcodes.ACC_ABSTRACT
    end

    # Ugh. So typically we might define a type for the main type,
    # then later we find the ClassDefinition that declares
    # the supertypes. We can't create a new type, or we'll lose
    # any methods already declared, so we have to change the supertypes
    # on the existing one. But now if you have multiple ClassDefinitions
    # for the same type with conflicting ancestors, we'll just pick the
    # last one, which is not ideal.
    if existing_type
      existing_type.setSupertypes(superclass, interfaceArray)
      existing_type.flags = flags
      return existing_future
    end

    mirror = MirahMirror.new(@context, type, flags,
                             superclass, interfaceArray)
    addClassIntrinsic(mirror)
    future = MirrorFuture.new(mirror, position)
    future
  end
  
  def publishType(future:TypeFuture)
    if future.kind_of?(MirrorFuture)
      mirror_future = MirrorFuture(future)
      publishType(MirahMirror(mirror_future.peekInferredType),mirror_future)
    end
  end
  
  def publishType(mirror:MirahMirror,future:MirrorFuture):void
    @loader.defineMirror(mirror.getAsmType, future)
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

  def loadMacroType(name:String):MirrorType
    macro_context = @context[Context] || @context
    types = macro_context[MirrorTypeSystem]
    MirrorType(types.loadNamedType(name).resolve)
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
    type = MirrorType(klass).unmeta
    member = MacroMember.create(macro_impl, type, @context)
    type.add(member)
    @@log.fine("Added macro #{member}")
  end

  def extendClass(classname:String, extensions:Class)
    type = BaseType(loadNamedType(classname).resolve)
    BytecodeMirrorLoader.extendClass(type, extensions)
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
        @object, MirrorObjectExtensions.class)
    bool = JVMType(getBooleanType.resolve)
    object_meta = getMetaType(@object_future).resolve
    methods = [
      Member.new(
          Opcodes.ACC_PUBLIC, @object, 'nil?', [],
          bool, MemberKind.IS_NULL),
      Member.new(
        Opcodes.ACC_PUBLIC, @object, 'kind_of?', [object_meta],
        bool, MemberKind.INSTANCEOF),
      Member.new(
        Opcodes.ACC_PUBLIC, @object, '===', [@object],
        bool, MemberKind.COMPARISON_OP),
      Member.new(
        Opcodes.ACC_PUBLIC, @object, '!==', [@object],
        bool, MemberKind.COMPARISON_OP),
    ]
    nullType = NullType(getNullType.resolve)
    methods.each do |m:Member|
      @object.add(m)
      nullType.add(m)
    end

    # null type needs == / != added explicitly still so that nil literals can receive ==
    [
      Member.new(
        Opcodes.ACC_PUBLIC, @object, '==', [@object], # TODO fix all the things
        bool, MemberKind.COMPARISON_OP),
      Member.new(
        Opcodes.ACC_PUBLIC, @object, '!=', [@object], #TODO fix all the things
        bool, MemberKind.COMPARISON_OP),
    ].each do |m: Member|
      nullType.add m
    end
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
      target = MirrorType(MirrorType(target).unmeta)
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
    member = MirahMethod.new(@context, position, flags, target, name, arguments, returnType, kind)

    returnFuture = AssignableTypeFuture(member.asyncReturnType)
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
    undeclared_future = @unpinned_field_futures[unpinned_key(target, name)]
    future = if undeclared_future
      AssignableTypeFuture(undeclared_future)
    else
      AssignableTypeFuture.new(position)
    end

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
        future = TypeFuture(Object(arg))
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

  def unpinned_key(resolvedTarget:MirrorType, name:String)
    [resolvedTarget, name]
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
    sb.append("TopLevel")
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