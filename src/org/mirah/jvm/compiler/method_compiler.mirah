# Copyright (c) 2012-2014 The Mirah project authors. All Rights Reserved.
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

import java.util.LinkedList
import org.mirah.util.Logger
import mirah.lang.ast.*
import org.mirah.jvm.types.CallType
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.GenericMethod
import org.mirah.jvm.mirrors.MirrorProxy
import org.mirah.jvm.mirrors.MethodLookup
import org.mirah.typer.ErrorType
import org.mirah.typer.Scope
import org.mirah.util.Context
import org.objectweb.asm.*
import org.objectweb.asm.Type as AsmType
import org.objectweb.asm.commons.GeneratorAdapter
import org.objectweb.asm.commons.Method as AsmMethod

import org.mirah.jvm.types.JVMTypeUtils

import java.util.List

interface InnerClassCompiler
  def context:Context; end
  def compileInnerClass(node:ClassDefinition, method:AsmMethod):void; end
end

class MethodCompiler < BaseCompiler
  def self.initialize:void
    @@log = Logger.getLogger(MethodCompiler.class.getName)
  end
  def initialize(compiler:InnerClassCompiler, klass:JVMType, flags:int, name:String)
    super(compiler.context)
    @flags = flags
    @name = name
    @locals = {}
    @args = {}
    @klass = klass
    @classCompiler = compiler
  end
  
  def isVoid
    @descriptor.getDescriptor.endsWith(")V")
  end
  
  def isStatic
    (@flags & Opcodes.ACC_STATIC) != 0
  end
  
  def bytecode
    @builder
  end
  
  def compile(cv:ClassVisitor, mdef:MethodDefinition):void
    @@log.fine "Compiling method #{mdef.name.identifier}"
    @builder = createBuilder(cv, mdef)
    context[AnnotationCompiler].compile(mdef.annotations, @builder)
    interpretCompilerLevelAnnotations(mdef)
    isExpression = isVoid() ? nil : Boolean.TRUE
    if (@flags & (Opcodes.ACC_ABSTRACT | Opcodes.ACC_NATIVE)) == 0
      prepareBinding(mdef)
      @lookingForDelegate = mdef.kind_of?(ConstructorDefinition)
      compileBody(mdef.body, isExpression, @returnType)
      body_position = if mdef.body_size > 0
        mdef.body(mdef.body_size - 1).position
      else
        mdef.body.position
      end
      returnValue(mdef)
    end
    @builder.endMethod
    @@log.fine "Finished method #{mdef.name.identifier}"
  end
  
  def interpretCompilerLevelAnnotations(mdef:MethodDefinition):void
    annotations = mdef.annotations
    
    annotations.size.times do |i|
      anno = annotations.get(i)
      
      if typer.getTypeOf(anno,anno.type.typeref).resolve.name.equals("java.lang.Override") # actually resolve the type, such that "$Override" also works and not only "$java.lang.Override"
        checkOverride(mdef)
      end
    end
  end
  
  # implements the java.lang.Override check
  #
  # The "java.lang.Override" annotation marks a method as inteded to override a method of a supertype.
  # If that to-be-overridden does not exist, then compiling this method should yield an error. 
  def checkOverride(mdef:MethodDefinition):void
    overrides = context[MethodLookup].findOverrides(MirrorProxy(klass).target, mdef.name.identifier, getInferredType(mdef).parameterTypes.size)
    type = getInferredType(mdef)
    
    overrides.each do |overridden:GenericMethod|
      if type.returnType.equals(overridden.returnType)
        if type.parameterTypes.equals(overridden.argumentTypes)
          return # Success. We have found a method we seem to override
        end
      end
    end
    
    raise "Method #{mdef} requires to override a method, but no matching method is actually overridden."  # Failure. We have not found a method we seem to override 
  end

  def compile(node:Node)
    visit(node, Boolean.TRUE)
  end

  def collectArgNames(mdef:MethodDefinition, bytecode:Bytecode):void
    args = mdef.arguments
    unless isStatic
      bytecode.declareArg('this', @selfType)
    end
    args.required_size.times do |a|
      arg = args.required(a)
      type = getInferredType(arg)
      bytecode.declareArg(arg.name.identifier, type)
    end
    args.optional_size.times do |a|
      optarg = args.optional(a)
      type = getInferredType(optarg)
      bytecode.declareArg(optarg.name.identifier, type)
    end
    if args.rest
      type = getInferredType(args.rest)
      bytecode.declareArg(args.rest.name.identifier, type)
    end
    args.required2_size.times do |a|
      arg = args.required2(a)
      type = getInferredType(arg)
      bytecode.declareArg(arg.name.identifier, type)
    end
  end

  def createBuilder(cv:ClassVisitor, mdef:MethodDefinition)
    @descriptor = descriptor(mdef)
    @selfType = JVMType(getScope(mdef).selfType.resolve)
    superclass = @selfType.superclass
    @superclass = superclass || JVMType(
        typer.type_system.get(nil, TypeRefImpl.new("java.lang.Object", false, false, nil)).resolve)
    builder = Bytecode.new(@flags, @descriptor, cv, mdef.findAncestor(Script.class).position.source)
    collectArgNames(mdef, builder)
    builder
  end
  
  def descriptor(mdef:MethodDefinition)
    type = getInferredType(mdef)

    if @name.endsWith("init>") || ":unreachable".equals(type.returnType.name)
      @returnType = JVMType(typer.type_system.getVoidType.resolve)
    else
      @returnType = JVMType(type.returnType)
    end

    methodDescriptor(@name, @returnType, type.parameterTypes)
  end
  
  def prepareBinding(mdef:MethodDefinition):void
    scope = getIntroducedScope(mdef)
    type = JVMType(scope.binding_type)
    if type
      # Figure out if we need to create a binding or if it already exists.
      # If this method is inside a ClosureDefinition, the binding is stored
      # in a field. Otherwise, this is the method enclosing the closure,
      # and it needs to create the binding.
      shouldCreateBinding = mdef.findAncestor(ClosureDefinition.class).nil?
      if shouldCreateBinding
        @builder.newInstance(type.getAsmType)
        @builder.dup
        args = AsmType[0]
        @builder.invokeConstructor(type.getAsmType, AsmMethod.new("<init>", AsmType.getType("V"), args))
        @builder.arguments.each do |arg: LocalInfo|
          # Save any captured method arguments into the binding
          if scope.isCaptured(arg.name)
            @builder.dup
            @builder.loadLocal(arg.name)
            @builder.putField(type.getAsmType, arg.name, arg.type)
          end
        end
      else
        @builder.loadThis
        @builder.getField(@selfType.getAsmType, 'binding', type.getAsmType)
      end
      @bindingType = type
      @binding = @builder.newLocal(type.getAsmType)
      @builder.storeLocal(@binding, type.getAsmType)
    end
  end
  
  def recordPosition(position:Position, atEnd:boolean=false)
    @builder.recordPosition(position, atEnd)
  end
  
  def defaultValue(type:JVMType)
    if JVMTypeUtils.isPrimitive(type)
      if 'long'.equals(type.name)
        @builder.push(long(0))
      elsif 'double'.equals(type.name)
        @builder.push(double(0))
      elsif 'float'.equals(type.name)
        @builder.push(float(0))
      else
        @builder.push(0)
      end
    else
      @builder.push(String(nil))
    end
  end
  
  def visitFixnum(node, expression)
    if expression
      isLong = "long".equals(getInferredType(node).name)
      recordPosition(node.position)
      if isLong
        @builder.push(node.value)
      else
        @builder.push(int(node.value))
      end
    end
  end
  def visitFloat(node, expression)
    if expression
      isFloat = "float".equals(getInferredType(node).name)
      recordPosition(node.position)
      if isFloat
        @builder.push(float(node.value))
      else
        @builder.push(node.value)
      end
    end
  end
  def visitBoolean(node, expression)
    if expression
      recordPosition(node.position)
      @builder.push(node.value ? 1 : 0)
    end
  end
  def visitCharLiteral(node, expression)
    if expression
      recordPosition(node.position)
      @builder.push(node.value)
    end
  end
  def visitSimpleString(node, expression)
    if expression
      recordPosition(node.position)
      @builder.push(node.value)
    end
  end
  def visitNull(node, expression)
    value = String(nil)
    if expression
      recordPosition(node.position)
      @builder.push(value)
    end
  end
  
  def visitSuper(node, expression)
    @lookingForDelegate = false
    @builder.loadThis
    paramTypes = LinkedList.new
    node.parameters_size.times do |i|
      param = node.parameters(i)
      compile(param)
      paramTypes.add(getInferredType(param))
    end
    recordPosition(node.position)
    result = getInferredType(node)
    method = if result.kind_of?(CallType)
      CallType(result).member
    else
      @superclass.getMethod(@name, paramTypes)
    end
    @builder.invokeSpecial(@superclass.getAsmType, methodDescriptor(method))
    if expression && isVoid
      @builder.loadThis
    elsif expression.nil? && !isVoid
      @builder.pop(@returnType)
    end
  end
  
  def visitLocalAccess(local, expression)
    if expression
      recordPosition(local.position)
      name = local.name.identifier

      proper_name = scoped_name(containing_scope(local), name)

      if @bindingType != nil && getScope(local).isCaptured(name)
        @builder.loadLocal(@binding)
        @builder.getField(@bindingType.getAsmType, proper_name, getInferredType(local).getAsmType)
      else
        @builder.loadLocal(proper_name)
      end
    end
  end

  def visitLocalAssignment(local, expression)
    name = local.name.identifier
    isCaptured = @bindingType != nil && getScope(local).isCaptured(name)

    if isCaptured
      @builder.loadLocal(@binding)
    end
    future = getScope(local).getLocalType(name, local.position)
    raise "error type found by compiler #{future.resolve}" if future.resolve.kind_of? ErrorType

    type = JVMType(
      future.resolve
      )
    valueType = getInferredType(local.value)
    if local.value.kind_of?(NodeList)
      compileBody(NodeList(local.value), Boolean.TRUE, type)
      valueType = type
    else
      visit(local.value, Boolean.TRUE)
    end

    if expression
      if isCaptured
        @builder.dupX1
      else
        @builder.dup
      end
    end
    
    recordPosition(local.position)
    @builder.convertValue(valueType, type)

    proper_name = scoped_name(containing_scope(local), name)
    if isCaptured
      @builder.putField(@bindingType.getAsmType, proper_name, type.getAsmType)
    else
      @builder.storeLocal(proper_name, type)
    end
  end
  
  def containing_scope(node: Named): Scope
    scope = getScope node
    name = node.name.identifier
    containing_scope scope, name
  end

  def containing_scope(node: RescueClause): Scope
    scope = getScope node.body
    name = node.name.identifier
    containing_scope scope, name
  end
  def containing_scope(scope: Scope, name: String)
    while _has_scope_something scope, name
      scope = scope.parent
    end
    scope
  end

  def _has_scope_something(scope: Scope, name: String): boolean
    not_shadowed = !scope.shadowed?(name)
    not_shadowed && !scope.parent.nil? && scope.parent.hasLocal(name)
  end

  def scoped_name scope: Scope, name: String
    if scope.shadowed? name
      "#{name}$#{System.identityHashCode(scope)}"
    else
      name
    end
  end

  def visitFunctionalCall(call, expression)
    raise "call to #{call.name.identifier}'s block has not been converted to a closure at #{call.position}" if call.block

    name = call.name.identifier

    # if this is the first line of a constructor, a call to 'initialize' is really a call to another
    # constructor.
    if @lookingForDelegate && name.equals("initialize")
      name = "<init>"
    end
    @lookingForDelegate = false

    compiler = CallCompiler.new(self, @builder, call.position, call.target, name, call.parameters, getInferredType(call))
    compiler.compile(expression != nil)
  end
  
  def visitCall(call, expression)
    raise "call to #{call.name.identifier}'s block has not been converted to a closure at #{call.position}" if call.block

    compiler = CallCompiler.new(self, @builder, call.position, call.target, call.name.identifier, call.parameters, getInferredType(call))
    compiler.compile(expression != nil)
  end
  
  def compileBody(node:NodeList, expression:Object, type:JVMType)
    if node.size == 0
      if expression
        defaultValue(type)
      else
        @builder.visitInsn(Opcodes.NOP)
      end
    else
      visitNodeList(node, expression)
    end
  end
  
  def visitIf(node, expression)
    elseLabel = @builder.newLabel
    endifLabel = @builder.newLabel
    compiler = ConditionCompiler.new(self, @builder)
    type = getInferredType(node)
    
    need_then = !expression.nil? || node.body_size > 0
    need_else = !expression.nil? || node.elseBody_size > 0

    if need_then
      compiler.negate
      compiler.compile(node.condition, elseLabel)
      compileBody(node.body, expression, type)
      @builder.goTo(endifLabel)
    else
      compiler.compile(node.condition, endifLabel)
    end
    
    @builder.mark(elseLabel)
    if need_else
      compileBody(node.elseBody, expression, type)
    end
    recordPosition(node.position, true)
    @builder.mark(endifLabel)
  end
  
  def visitImplicitNil(node, expression)
    if expression
      defaultValue(getInferredType(node))
    end
  end
  
  def visitReturn(node, expression)
    compile(node.value) unless isVoid
    handleEnsures(node, MethodDefinition.class)
    type = getInferredType node.value
    @builder.convertValue(type, @returnType) unless isVoid || type.nil?
    @builder.returnValue
  end
  
  def visitCast(node, expression)
    compile(node.value)
    from = getInferredType(node.value)
    to = getInferredType(node)
    @builder.convertValue(from, to)
    @builder.pop(to) unless expression
  end
  
  def visitFieldAccess(node, expression)
    klass = @selfType.getAsmType
    name = node.name.identifier
    type = getInferredType(node)
    isStatic = node.isStatic || self.isStatic
    if isStatic
      recordPosition(node.position)
      @builder.getStatic(klass, name, type.getAsmType)
    else
      @builder.loadThis
      recordPosition(node.position)
      @builder.getField(klass, name, type.getAsmType)
    end
    unless expression
      @builder.pop(type)
    end
  end
  
  def visitFieldAssign(node, expression)
    klass = @selfType.getAsmType
    name = node.name.identifier
    raise IllegalArgumentException.new if name.endsWith("=")
    isStatic = node.isStatic || self.isStatic
    type = @klass.getDeclaredField(node.name.identifier).returnType
    @builder.loadThis unless isStatic
    compile(node.value)
    valueType = getInferredType(node.value)
    if expression
      if isStatic
        @builder.dup(valueType)
      else
        @builder.dupX1(valueType)
      end
    end
    @builder.convertValue(valueType, type)
    
    recordPosition(node.position)
    if isStatic
      @builder.putStatic(klass, name, type.getAsmType)
    else
      @builder.putField(klass, name, type.getAsmType)
    end
  end
  
  def visitEmptyArray(node, expression)
    compile(node.size)
    recordPosition(node.position)
    type = getInferredType(node).getComponentType
    @builder.newArray(type.getAsmType)
    @builder.pop unless expression
  end
  
  def visitAttrAssign(node, expression)
    compiler = CallCompiler.new(
        self, @builder, node.position, node.target,
        "#{node.name.identifier}_set", [node.value], getInferredType(node))
    compiler.compile(expression != nil)
  end
  
  def visitStringConcat(node, expression)
    visit(node.strings, expression)
  end
  
  def visitStringPieceList(node, expression)
    if node.size == 0
      if expression
        recordPosition(node.position)
        @builder.push("")
      end
    elsif node.size == 1 && node.get(0).kind_of?(SimpleString)
      visit(node.get(0), expression)
    else
      compiler = StringCompiler.new(self)
      compiler.compile(node, expression != nil)
    end
  end
  
  def visitRegex(node, expression)
    # TODO regex flags
    compile(node.strings)
    recordPosition(node.position)
    pattern = findType("java.util.regex.Pattern")
    @builder.invokeStatic(pattern.getAsmType, methodDescriptor("compile", pattern, [findType("java.lang.String")]))
    @builder.pop unless expression
  end
  
  def visitNot(node, expression)
    visit(node.value, expression)
    if expression
      recordPosition(node.position)
      done = @builder.newLabel
      elseLabel = @builder.newLabel
      type = getInferredType(node.value)
      if JVMTypeUtils.isPrimitive(type)
        @builder.ifZCmp(GeneratorAdapter.EQ, elseLabel)
      else
        @builder.ifNull(elseLabel)
      end
      @builder.push(0)
      @builder.goTo(done)
      @builder.mark(elseLabel)
      @builder.push(1)
      @builder.mark(done)
    end
  end
  
  def returnValue(mdef:MethodDefinition)
    body = mdef.body
    type = getInferredType(body)
    unless isVoid || type.nil? || @returnType.assignableFrom(type)
      # TODO this error should be caught by the typer
      body_position = if body.size > 0
        body.get(body.size - 1).position
      else
        body.position
      end
      reportError("Invalid return type #{type.name}, expected #{@returnType.name}", body_position)
    end
    @builder.convertValue(type, @returnType) unless isVoid || type.nil?
    @builder.returnValue
  end
  
  def visitSelf(node, expression)
    if expression
      recordPosition(node.position)
      @builder.loadThis
    end
  end

  def visitImplicitSelf(node, expression)
    if expression
      recordPosition(node.position)
      @builder.loadThis
    end
  end
  
  def visitLoop(node, expression)
    old_loop = @loop
    @loop = LoopCompiler.new(@builder)
    
    visit(node.init, nil)
    
    predicate = ConditionCompiler.new(self, @builder)
    
    preLabel = @builder.newLabel
    unless node.skipFirstCheck
      @builder.mark(@loop.getNext) unless node.post_size > 0
      # Jump out of the loop if the condition is false
      predicate.negate unless node.negative
      predicate.compile(node.condition, @loop.getBreak)
      # un-negate the predicate
      predicate.negate
    end
      
    @builder.mark(preLabel)
    visit(node.pre, nil)
    
    @builder.mark(@loop.getRedo)
    visit(node.body, nil) if node.body
    
    if node.skipFirstCheck || node.post_size > 0
      @builder.mark(@loop.getNext)
      visit(node.post, nil)
      # Loop if the condition is true
      predicate.negate if node.negative
      predicate.compile(node.condition, preLabel)
    else
      @builder.goTo(@loop.getNext)
    end
    @builder.mark(@loop.getBreak)
    recordPosition(node.position, true)

    # loops always evaluate to null
    @builder.pushNil if expression
  ensure
    @loop = old_loop
  end
  
  def visitBreak(node, expression)
    if @loop
      handleEnsures(node, Loop.class)
      @builder.goTo(@loop.getBreak)
    else
      reportError("Break outside of loop", node.position)
    end
  end
  
  def visitRedo(node, expression)
    if @loop
      handleEnsures(node, Loop.class)
      @builder.goTo(@loop.getRedo)
    else
      reportError("Redo outside of loop", node.position)
    end
  end
  
  def visitNext(node, expression)
    if @loop
      handleEnsures(node, Loop.class)
      @builder.goTo(@loop.getNext)
    else
      reportError("Next outside of loop", node.position)
    end
  end
  
  def visitArray(node, expression)
    @arrays ||= ArrayCompiler.new(self, @builder)
    @arrays.compile(node)
    @builder.pop unless expression
  end
  
  def visitHash(node, expression)
    @hashes ||= HashCompiler.new(self, @builder)
    @hashes.compile(node)
    @builder.pop unless expression
  end
  
  def visitRaise(node, expression)
    compile(node.args(0))
    recordPosition(node.position)
    @builder.throwException
  end
  
  def visitRescue(node, expression)
    start = @builder.mark
    start_offset = @builder.instruction_count
    bodyEnd = @builder.newLabel
    bodyIsExpression = if expression.nil? || node.elseClause.size > 0
      nil
    else
      Boolean.TRUE
    end
    visit(node.body, bodyIsExpression)
    end_offset = @builder.instruction_count
    @builder.mark(bodyEnd)
    visit(node.elseClause, expression) if node.elseClause.size > 0
    
    # If the body was empty, it can't throw any exceptions
    # so we must not emit a try/catch.
    unless start_offset == end_offset
      done = @builder.newLabel
      @builder.goTo(done)
      node.clauses_size.times do |clauseIndex|
        clause = node.clauses(clauseIndex)
        clause.types_size.times do |typeIndex|
          type = getInferredType(clause.types(typeIndex))
          @builder.catchException(start, bodyEnd, type.getAsmType)
        end
        if clause.name
          recordPosition(clause.name.position)
          proper_name = scoped_name(containing_scope(clause), clause.name.identifier)

          @builder.storeLocal(proper_name, AsmType.getType('Ljava/lang/Throwable;'))
        else
          @builder.pop
        end
        compileBody(clause.body, expression, getInferredType(node))
        @builder.goTo(done)
      end
      @builder.mark(done)
    end
  end
  
  def handleEnsures(node:Node, klass:Class):void
    while node.parent
      visit(Ensure(node).ensureClause, nil) if node.kind_of?(Ensure)
      break if klass.isInstance(node)
      node = node.parent
    end
  end
  
  def visitEnsure(node, expression)
    start = @builder.mark
    bodyEnd = @builder.newLabel
    start_offset = @builder.instruction_count
    visit(node.body, expression)
    end_offset = @builder.instruction_count
    @builder.mark(bodyEnd)
    visit(node.ensureClause, nil)
    
    # If the body was empty, it can't throw any exceptions
    # so we must not emit a try/catch.
    unless start_offset == end_offset
      done = @builder.newLabel
      @builder.goTo(done)
      @builder.catchException(start, bodyEnd, nil)
      visit(node.ensureClause, nil)
      @builder.throwException
      @builder.mark(done)
    end
  end
  
  def visitNoop(node, expression)
  end
  
  def visitClassDefinition(node, expression)
    @classCompiler.compileInnerClass(node, @descriptor)
  end
  
  def visitClosureDefinition(node, exporession)
    @classCompiler.compileInnerClass(node, @descriptor)
  end
  
  def visitBindingReference(node, expression)
    @builder.loadLocal(@binding) if expression
  end
end