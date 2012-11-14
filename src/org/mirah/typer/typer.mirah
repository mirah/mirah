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

package org.mirah.typer

import java.util.*
import java.util.logging.Logger
import mirah.lang.ast.*
import org.mirah.macros.JvmBackend
import org.mirah.macros.MacroBuilder

# Type inference engine.
# Makes a single pass over the AST nodes building a graph of the type
# dependencies. Whenever a new type is learned or a type changes any dependent
# types get updated.
#
# An important feature is that types will change over time.
# The first time an assignment to a variable resolves, the typer will pick that
# type for the variable. When a new assignment resolves, two things can happen:
#  - if the assigned type is compatible with the old, just continue.
#  - otherwise, widen the inferred type to include both and update any dependencies.
# This also allows the typer to handle recursive calls. Consider fib for example:
#   def fib(i:int); if i < 2 then 1 else fib(i - 1) + fib(i - 2) end; end
# The type of fib() depends on the if statement, which also depends on the type
# of fib(). The first branch infers first though, marking the if statement
# as type 'int'. This updates fib() to also be type 'int'. This in turn causes
# the if statement to check that both its branches are compatible, and they are
# so the method is resolved.
#
# Some nodes can have multiple meanings. For example, a VCall could mean a
# LocalAccess or a FunctionalCall. The typer will try each possibility,
# and update the AST tree with the one that doesn't infer as an error. There
# is always a priority implied when multiple options succeed. For example,
# a LocalAccess always wins over a FunctionalCall.
#
# This typer is type system independent. It relies on a TypeSystem and a Scoper
# to provide the types for methods, literals, variables, etc.
class Typer < SimpleNodeVisitor
  def self.initialize:void
    @@log = Logger.getLogger(Typer.class.getName)
  end

  def initialize(types:TypeSystem, scopes:Scoper, jvm_backend:JvmBackend)
    @trueobj = java::lang::Boolean.valueOf(true)
    @futures = HashMap.new
    @types = types
    @scopes = scopes
    @closures = ClosureBuilder.new(self)
    @macros = MacroBuilder.new(self, jvm_backend)
  end

  def macro_compiler
    @macros
  end

  def type_system
    @types
  end

  def scoper
    @scopes
  end

  def getInferredType(node:Node)
    TypeFuture(@futures[node])
  end

  def inferTypeName(node:TypeName)
    @futures[node] ||= @types.get(@scopes.getScope(node), node.typeref)
    TypeFuture(@futures[node])
  end

  def infer(node:Node, expression:boolean=true)
    @@log.entering("Typer", "infer", "infer(#{node})")
    return nil if node.nil?
    type = @futures[node]
    if type.nil?
      type = node.accept(self, expression ? @trueobj : nil)
      @futures[node] = type
    end
    TypeFuture(type)
  end

  def infer(node:Object, expression:boolean=true)
    infer(Node(node), expression)
  end

  def inferAll(nodes:NodeList)
    types = ArrayList.new
    nodes.each {|n| types.add(infer(n))} if nodes
    types
  end

  def inferAll(nodes:AnnotationList)
    types = ArrayList.new
    nodes.each {|n| types.add(infer(n))} if nodes
    types
  end

  def inferAll(arguments:Arguments)
    types = ArrayList.new
    arguments.required.each {|a| types.add(infer(a))} if arguments.required
    arguments.optional.each {|a| types.add(infer(a))} if arguments.optional
    types.add(infer(arguments.rest)) if arguments.rest
    arguments.required2.each {|a| types.add(infer(a))} if arguments.required2
    types.add(infer(arguments.block)) if arguments.block
    types
  end

  def inferAll(scope:Scope, typeNames:TypeNameList)
    types = ArrayList.new
    typeNames.each {|n| types.add(inferTypeName(TypeName(n)))}
    types
  end

  def defaultNode(node, expression)
    ErrorType.new([["Inference error: unsupported node #{node}", node.position]])
  end

  def logger
    @@log
  end

  def visitVCall(call, expression)
    scope = @scopes.getScope(call)
    targetType = scope.selfType
    targetType = @types.getMetaType(targetType) if scope.context.kind_of?(ClassDefinition)
    methodType = CallFuture.new(@types, scope, targetType, Collections.emptyList, call)
    fcall = FunctionalCall.new(call.position, Identifier(call.name.clone), nil, nil)
    fcall.setParent(call.parent)
    @futures[fcall] = methodType


    # This might actually be a local or primitive access instead of a method call,
    # so try them all.
    # TODO should probably replace this with a FunctionalCall node if that's the
    # right one so the compiler doesn't have to deal with an extra node.
    primitive = Constant.new(call.position, call.name)
    primitive.setParent(call.parent)
    local = LocalAccess.new(call.position, call.name)
    local.setParent(call.parent)
    options = [infer(primitive, true), primitive, infer(local, true), local, methodType, fcall]
    current_node = Node(call)
    typer = self
    future = DelegateFuture.new
    future.type = infer(local, true)
    picker = PickFirst.new(options) do |typefuture, _node|
      node = Node(_node)
      picked_type = typefuture.resolve
      if picked_type.kind_of?(InlineCode)
        typer.logger.fine("Expanding macro #{call}")
        node = InlineCode(picked_type).expand(fcall, typer)
        need_to_infer = true
      end
      if current_node.parent.nil?
        typer.logger.fine("Unable to replace #{current_node} with #{node}")
      else
        node = current_node.parent.replaceChild(current_node, node)
        future.type = typer.infer(node, expression != nil)
      end
      current_node = node
    end
    future.position = call.position
    future.error_message = "Unable to find local or method '#{call.name.identifier}'"
    future
  end

  def visitFunctionalCall(call, expression)
    scope = @scopes.getScope(call)
    mergeUnquotes(call.parameters)
    parameters = inferAll(call.parameters)
    parameters.add(infer(call.block, true)) if call.block
    delegate = DelegateFuture.new
    targetType = scope.selfType
    targetType = @types.getMetaType(targetType) if scope.context.kind_of?(ClassDefinition)
    methodType = CallFuture.new(@types, scope, targetType, parameters, call)
    delegate.type = methodType
    typer = self
    methodType.onUpdate do |x, resolvedType|
      if resolvedType.kind_of?(InlineCode)
        typer.logger.fine("Expanding macro #{call}")
        node = InlineCode(resolvedType).expand(call, typer)
        node = call.parent.replaceChild(call, node)
        delegate.type = typer.infer(node, expression != nil)
      else
        delegate.type = methodType
      end
    end
    if call.parameters.size == 1
      # This might actually be a cast instead of a method call, so try
      # both. If the cast works, we'll go with that. If not, we'll leave
      # the method call.
      items = LinkedList.new
      cast = Cast.new(call.position, TypeName(call.typeref), Node(call.parameters.get(0).clone))
      castType = @types.get(scope, call.typeref)
      items.add(castType)
      items.add(cast)
      items.add(delegate)
      items.add(nil)
      TypeFuture(PickFirst.new(items) do |type, arg|
        if arg != nil
          # We chose the cast.
          call.parent.replaceChild(call, cast)
          typer.infer(cast, expression != nil)
        end
      end)
    else
      delegate
    end
  end

  def visitElemAssign(assignment, expression)
    value_type = infer(assignment.value)
    value = assignment.value
    assignment.removeChild(value)
    if value_type.kind_of?(NarrowingTypeFuture)
      narrowingCall(@scopes.getScope(assignment),
                    infer(assignment.target),
                    '[]=',
                    inferAll(assignment.args),
                    NarrowingTypeFuture(value_type),
                    assignment.position)
    end
    call = Call.new(assignment.position, assignment.target, SimpleString.new('[]='), nil, nil)
    call.parameters = assignment.args
    if expression
      temp = @scopes.getScope(assignment).temp('val')
      call.parameters.add(LocalAccess.new(SimpleString.new(temp)))
      newNode = Node(NodeList.new([
        LocalAssignment.new(SimpleString.new(temp), value),
        call,
        LocalAccess.new(SimpleString.new(temp))
      ]))
    else
      call.parameters.add(value)
      newNode = Node(call)
    end
    newNode = assignment.parent.replaceChild(assignment, newNode)
    infer(newNode)
  end

  def visitCall(call, expression)
    target = infer(call.target)
    mergeUnquotes(call.parameters)
    parameters = inferAll(call.parameters)
    parameters.add(infer(call.block, true)) if call.block
    methodType = CallFuture.new(@types, @scopes.getScope(call), target, parameters, call)
    delegate = DelegateFuture.new
    delegate.type = methodType
    typer = self
    current_node = Node(call)
    methodType.onUpdate do |x, resolvedType|
      if resolvedType.kind_of?(InlineCode)
        typer.logger.fine("Expanding macro #{call}")
        node = InlineCode(resolvedType).expand(call, typer)
        node = current_node.parent.replaceChild(current_node, node)
        current_node = node
        delegate.type = typer.infer(node, expression != nil)
      else
        delegate.type = methodType
      end
    end
    if  call.parameters.size == 1
      # This might actually be a cast or array instead of a method call, so try
      # both. If the cast works, we'll go with that. If not, we'll leave
      # the method call.
      is_array = '[]'.equals(call.name.identifier)
      if is_array
        typeref = TypeName(call.target).typeref if call.target.kind_of?(TypeName)
      else
        typeref = call.typeref(true)
      end
      scope = @scopes.getScope(call)
      if typeref
        if is_array
          array = EmptyArray.new(call.position, typeref, call.parameters(0))
          newNode = Node(array)
          newType = @types.getArrayType(@types.get(scope, typeref))
          @scopes.copyScopeFrom(call, newNode)
        else
          cast = Cast.new(call.position, TypeName(typeref), Node(call.parameters(0).clone))
          newNode = Node(cast)
          newType = @types.get(scope, typeref)
        end
        items = LinkedList.new
        items.add(newType)
        items.add(newNode)
        items.add(delegate)
        items.add(nil)
        TypeFuture(PickFirst.new(items) do |type, arg|
          if arg != nil
            call.parent.replaceChild(call, newNode)
            typer.infer(newNode, expression != nil)
          end
        end)
      else
        delegate
      end
    else
      delegate
    end
  end

  def visitAttrAssign(call, expression)
    target = infer(call.target)
    value = infer(call.value)
    name = call.name.identifier
    setter = "#{name}_set"
    scope = @scopes.getScope(call)
    if (value.kind_of?(NarrowingTypeFuture))
      narrowingCall(scope, target, setter, Collections.emptyList, NarrowingTypeFuture(value), call.position)
    end
    CallFuture.new(@types, scope, target, setter, [value], nil, call.position)
  end

  def narrowingCall(scope:Scope,
                    target:TypeFuture,
                    name:String,
                    param_types:List,
                    value:NarrowingTypeFuture,
                    position:Position):void
    # Try looking up both the wide type and the narrow type.
    wide_params = LinkedList.new(param_types)
    wide_params.add(value.wide_future)
    wide_call = CallFuture.new(@types, scope, target, name, wide_params, nil, position)

    narrow_params = LinkedList.new(param_types)
    narrow_params.add(value.narrow_future)
    narrow_call = CallFuture.new(@types, scope, target, name, narrow_params, nil, position)

    # If there's a match for the wide type (or both are errors) we always use
    # the wider one.
    wide_is_error = true
    narrow_is_error = true
    wide_call.onUpdate do |x, resolved|
      wide_is_error = resolved.isError
      if wide_is_error && !narrow_is_error
        value.narrow
      else
        value.widen
      end
    end
    narrow_call.onUpdate do |x, resolved|
      narrow_is_error = resolved.isError
      if wide_is_error && !narrow_is_error
        value.narrow
      else
        value.widen
      end
    end
  end

  def visitCast(cast, expression)
    # TODO check for compatibility
    infer(cast.value)
    @types.get(@scopes.getScope(cast), cast.type.typeref)
  end

  def visitColon2(colon2, expression)
    @types.getMetaType(@types.get(@scopes.getScope(colon2), colon2.typeref))
  end

  def visitSuper(node, expression)
    method = MethodDefinition(node.findAncestor(MethodDefinition.class))
    scope = @scopes.getScope(node)
    target = @types.getSuperClass(scope.selfType)
    parameters = inferAll(node.parameters)
    parameters.add(infer(node.block, true)) if node.block
    CallFuture.new(@types, scope, target, method.name.identifier, parameters, nil, node.position)
  end

  def visitZSuper(node, expression)
    method = MethodDefinition(node.findAncestor(MethodDefinition.class))
    locals = LinkedList.new
    [ method.arguments.required,
        method.arguments.optional,
        method.arguments.required2].each do |args|
      Iterable(args).each do |arg|
        farg = FormalArgument(arg)
        local = LocalAccess.new(farg.position, farg.name)
        @scopes.copyScopeFrom(farg, local)
        infer(local, true)
        locals.add(local)
      end
    end
    replacement = Super.new(node.position, locals, nil)
    infer(node.parent.replaceChild(node, replacement), expression != nil)
  end

  def visitClassDefinition(classdef, expression)
    classdef.annotations.each {|a| infer(a)}
    scope = @scopes.getScope(classdef)
    interfaces = inferAll(scope, classdef.interfaces)
    superclass = @types.get(scope, classdef.superclass.typeref) if classdef.superclass
    name = if classdef.name
      classdef.name.identifier
    end
    type = @types.defineType(scope, classdef, name, superclass, interfaces)
    new_scope = @scopes.addScope(classdef)
    new_scope.selfType = type
    infer(classdef.body, false) if classdef.body
    type
  end

  def visitClosureDefinition(classdef, expression)
    visitClassDefinition(classdef, expression)
  end

  def visitInterfaceDeclaration(idef, expression)
    visitClassDefinition(idef, expression)
  end

  def visitFieldDeclaration(decl, expression)
    decl.annotations.each {|a| infer(a)}
    scope = @scopes.getScope(decl)
    targetType = scope.selfType
    targetType = @types.getMetaType(targetType) if decl.isStatic
    @types.getFieldType(targetType, decl.name.identifier, decl.position).declare(
        @types.get(scope, decl.type.typeref), decl.position)
  end

  def visitFieldAssign(field, expression)
    field.annotations.each {|a| infer(a)}
    targetType = @scopes.getScope(field).selfType
    targetType = @types.getMetaType(targetType) if field.isStatic
    value = infer(field.value, true)
    @types.getFieldType(targetType, field.name.identifier, field.position).assign(value, field.position)
  end

  def visitFieldAccess(field, expression)
    targetType = @scopes.getScope(field).selfType
    targetType = @types.getMetaType(targetType) if field.isStatic
    @types.getFieldType(targetType, field.name.identifier, field.position)
  end

  def visitConstant(constant, expression)
    @types.getMetaType(@types.get(@scopes.getScope(constant), constant.typeref))
  end

  def visitIf(stmt, expression)
    infer(stmt.condition, true)
    a = infer(stmt.body, expression != nil) if stmt.body
    b = infer(stmt.elseBody, expression != nil) if stmt.elseBody
    if expression && a && b
      type = AssignableTypeFuture.new(stmt.position)
      type.assign(a, stmt.body.position)
      type.assign(b, stmt.elseBody.position)
      TypeFuture(type)
    else
      a || b
    end
  end

  def visitLoop(node, expression)
    enhanceLoop(node)
    infer(node.condition, true)
    infer(node.body, false)
    infer(node.init, false)
    infer(node.pre, false)
    infer(node.post, false)
    @types.getNullType()
  end

  def visitReturn(node, expression)
    type = if node.value
      infer(node.value)
    else
      @types.getVoidType()
    end
    method = MethodDefinition(node.findAncestor(MethodDefinition.class))
    parameters = inferAll(method.arguments)
    target = @scopes.getScope(method).selfType
    @types.getMethodDefType(target, method.name.identifier, parameters).returnType.assign(type, node.position)
  end

  def visitBreak(node, expression)
    @types.getNullType()
  end

  def visitNext(node, expression)
    @types.getNullType()
  end

  def visitRedo(node, expression)
    @types.getNullType()
  end

  def visitRaise(node, expression)
    # Ok, this is complicated. There's three acceptable syntaxes
    #  - raise exception_object
    #  - raise ExceptionClass, *constructor_args
    #  - raise *args_for_default_exception_class_constructor
    # We need to figure out which one is being used, and replace the
    # args with a single exception node.

    # Start by saving the old args and creating a new, empty arg list
    exceptions = ArrayList.new
    old_args = node.args
    node.args = NodeList.new(node.args.position)

    # Create a node for syntax 1 if possible.
    if old_args.size == 1
      new_node = Node(Node(old_args.get(0)).clone)
      @scopes.copyScopeFrom(node, new_node)
      new_type = BaseTypeFuture.new(new_node.position)
      error = ErrorType.new([["Not an expression", new_node.position]])
      infer(new_node).onUpdate do |x, resolvedType|
        # We need to make sure they passed an object, not just a class name
        if resolvedType.isMeta
          new_type.resolved(error)
        else
          new_type.resolved(resolvedType)
        end
      end
      # Now we need to make sure the object is an exception, otherwise we
      # need to use a different syntax.
      exceptionType = AssignableTypeFuture.new(new_node.position)
      exceptionType.declare(@types.getBaseExceptionType(), node.position)
      assignment = exceptionType.assign(new_type, node.position)
      exceptions.add(assignment)
      exceptions.add(new_node)
    end

    # Create a node for syntax 2 if possible.
    if old_args.size > 0
      targetNode = Node(Node(old_args.get(0)).clone)
      params = ArrayList.new
      1.upto(old_args.size - 1) {|i| params.add(Node(old_args.get(i)).clone)}
      call = Call.new(node.position, targetNode, SimpleString.new(node.position, 'new'), params, nil)
      @scopes.copyScopeFrom(node, call)
      exceptions.add(infer(call))
      exceptions.add(call)
    end

    # Create a node for syntax 3.
    class_name = @types.getDefaultExceptionType().resolve.name
    targetNode = Constant.new(node.position, SimpleString.new(node.position, class_name))
    params = ArrayList.new
    old_args.each {|a| params.add(Node(a).clone)}
    call = Call.new(node.position, targetNode, SimpleString.new(node.position, 'new'), params, nil)
    @scopes.copyScopeFrom(node, call)
    exceptions.add(infer(call))
    exceptions.add(call)

    # Now we'll try all of these, ignoring any that cause an inference error.
    # Then we'll take the first that succeeds, in the order listed above.
    exceptionPicker = PickFirst.new(exceptions) do |type, pickedNode|
      if node.args.size == 0
        node.args.add(Node(pickedNode))
      else
        node.args.set(0, Node(pickedNode))
      end
    end

    # We need to ensure that the chosen node is an exception.
    # So create a dummy type declared as an exception, and assign
    # the picker to it.
    exceptionType = AssignableTypeFuture.new(node.position)
    exceptionType.declare(@types.getBaseExceptionType(), node.position)
    assignment = exceptionType.assign(exceptionPicker, node.position)

    # Now we're ready to return our type. It should be UnreachableType.
    # But if none of the nodes is an exception, we need to return
    # an error.
    myType = BaseTypeFuture.new(node.position)
    unreachable = UnreachableType.new
    assignment.onUpdate do |x, resolved|
      if resolved.name == ':error'
        myType.resolved(resolved)
      else
        myType.resolved(unreachable)
      end
    end
    myType
  end

  def visitRescueClause(clause, expression)
    scope = @scopes.addScope(clause)
    scope.parent = @scopes.getScope(clause)
    name = clause.name
    if clause.types_size == 0
      clause.types.add(TypeRefImpl.new(@types.getDefaultExceptionType().resolve.name,
                                       false, false, clause.position))
    end
    if name
      scope.shadow(name.identifier)
      exceptionType = @types.getLocalType(scope, name.identifier, name.position)
      clause.types.each do |_t|
        t = TypeName(_t)
        exceptionType.assign(inferTypeName(t), t.position)
      end
    else
      inferAll(scope.parent, clause.types)
    end
    # What if body is nil?
    infer(clause.body, expression != nil)
  end

  def visitRescue(node, expression)
    bodyType = infer(node.body, expression && node.elseClause.nil?) if node.body
    elseType = infer(node.elseClause, expression != nil) if node.elseClause
    if expression
      myType = AssignableTypeFuture.new(node.position)
      if node.elseClause
        myType.assign(elseType, node.elseClause.position)
      else
        myType.assign(bodyType, node.body.position)
      end
    end
    node.clauses.each do |clause|
      clauseType = infer(clause, expression != nil)
      myType.assign(clauseType, Node(clause).position) if expression
    end
    TypeFuture(myType) || @types.getNullType
  end

  def visitEnsure(node, expression)
    infer(node.ensureClause, false)
    infer(node.body, expression != nil)
  end

  def visitArray(array, expression)
    mergeUnquotes(array.values)
    component = AssignableTypeFuture.new(array.position)
    array.values.each do |v|
      node = Node(v)
      component.assign(infer(node, true), node.position)
    end
    @types.getArrayLiteralType(component, array.position)
  end

  def visitFixnum(fixnum, expression)
    @types.getFixnumType(fixnum.value)
  end

  def visitFloat(number, expression)
    @types.getFloatType(number.value)
  end

  def visitNot(node, expression)
    type = BaseTypeFuture.new(node.position)
    null_type = @types.getNullType.resolve
    boolean_type = @types.getBooleanType.resolve
    infer(node.value).onUpdate do |x, resolved|
      if (null_type.assignableFrom(resolved) ||
          boolean_type.assignableFrom(resolved))
        type.resolved(boolean_type)
      else
        type.resolved(ErrorType.new([["#{resolved} not compatible with boolean", node.position]]))
      end
    end
    type
  end

  def visitHash(hash, expression)
    keyType = AssignableTypeFuture.new(hash.position)
    valueType = AssignableTypeFuture.new(hash.position)
    hash.each do |e|
      entry = HashEntry(e)
      keyType.assign(infer(entry.key, true), entry.key.position)
      valueType.assign(infer(entry.value, true), entry.value.position)
      infer(entry, false)
    end
    @types.getHashLiteralType(keyType, valueType, hash.position)
  end
  
  def visitHashEntry(entry, expression)
    @types.getVoidType
  end

  def visitRegex(regex, expression)
    regex.strings.each {|r| infer(r)}
    @types.getRegexType()
  end

  def visitSimpleString(string, expression)
    @types.getStringType()
  end

  def visitStringConcat(string, expression)
    string.strings.each {|s| infer(s)}
    @types.getStringType()
  end

  def visitStringEval(string, expression)
    infer(string.value)
    @types.getStringType()
  end

  def visitBoolean(bool, expression)
    @types.getBooleanType()
  end

  def visitNull(node, expression)
    @types.getNullType()
  end

  def visitCharLiteral(node, expression)
    @types.getCharType(node.value)
  end

  def visitSelf(node, expression)
    @scopes.getScope(node).selfType
  end

  def visitTypeRefImpl(typeref, expression)
    @types.get(@scopes.getScope(typeref), typeref)
  end

  def visitLocalDeclaration(decl, expression)
    scope = @scopes.getScope(decl)
    type = @types.get(scope, decl.type.typeref)
    @types.getLocalType(scope, decl.name.identifier, decl.position).declare(type, decl.position)
  end

  def visitLocalAssignment(local, expression)
    value = infer(local.value, true)
    @types.getLocalType(@scopes.getScope(local), local.name.identifier, local.position).assign(value, local.position)
  end

  def visitLocalAccess(local, expression)
    @types.getLocalType(@scopes.getScope(local), local.name.identifier, local.position)
  end

  def visitNodeList(body, expression)
    i = 0
    while i < body.size - 1
      infer(body.get(i), false)
      i += 1
    end
    if body.size > 0
      infer(body.get(body.size - 1), expression != null)
    else
      @types.getImplicitNilType()
    end
  end

  def visitClassAppendSelf(node, expression)
    scope = @scopes.addScope(node)
    scope.selfType = @types.getMetaType(@scopes.getScope(node).selfType)
    infer(node.body, false)
    @types.getNullType()
  end

  def visitNoop(noop, expression)
    @types.getVoidType()
  end

  def visitScript(script, expression)
    scope = @scopes.addScope(script)
    @types.addDefaultImports(scope)
    scope.selfType = @types.getMainType(scope, script)
    type = infer(script.body, false)
    type
  end

  def visitAnnotation(anno, expression)
    anno.values_size.times do |i|
      infer(anno.values(i).value)
    end
    @types.get(@scopes.getScope(anno), anno.type.typeref)
  end

  def visitImport(node, expression)
    scope = @scopes.getScope(node)
    fullName = node.fullName.identifier
    simpleName = node.simpleName.identifier
    scope.import(fullName, simpleName)
    unless '*'.equals(simpleName)
      @types.get(scope, TypeName(node.fullName).typeref)
    end
    @types.getVoidType()
  end

  def visitPackage(node, expression)
    if node.body
      scope = @scopes.addScope(node)
      scope.package = node.name.identifier
      infer(node.body, false)
    else
      # TODO this makes things complicated. Probably package should be a property of
      # Script, and Package nodes should require a body.
      scope = @scopes.getScope(node)
      scope.package = node.name.identifier
    end
    @types.getVoidType()
  end

  def visitEmptyArray(node, expression)
    infer(node.size)
    @types.getArrayType(@types.get(@scopes.getScope(node), node.type.typeref))
  end

  def visitUnquote(node, expression)
    # Convert the unquote into a NodeList and replace it with the NodeList.
    # TODO(ribrdb) do these need to be cloned?
    nodes = node.nodes
    replacement = if nodes.size == 1
      Node(nodes.get(0))
    else
      NodeList.new(node.position, nodes)
    end
    replacement = node.parent.replaceChild(node, replacement)
    infer(replacement, expression != nil)
  end

  def visitUnquoteAssign(node, expression)
    replacement = Node(nil)
    object = node.unquote.object
    if object.kind_of?(FieldAccess)
      fa = FieldAccess(node.name)
      replacement = FieldAssign.new(fa.position, fa.name, node.value, nil)
    else
      replacement = LocalAssignment.new(node.position, node.name, node.value)
    end
    replacement = node.parent.replaceChild(node, replacement)
    infer(replacement, expression != nil)
  end

  def visitArguments(args, expression)
    # Merge in any unquoted arguments first.
    it = args.required.listIterator
    mergeArgs(args, it, it, args.optional.listIterator(args.optional_size), args.required2.listIterator(args.required2_size))
    it = args.optional.listIterator
    mergeArgs(args, it, args.required.listIterator(args.required_size), it, args.required2.listIterator(args.required2_size))
    it = args.required.listIterator
    mergeArgs(args, it, args.required.listIterator(args.required_size), args.optional.listIterator(args.optional_size), it)
    # Then do normal type inference.
    inferAll(args)
    @types.getVoidType()
  end

  def mergeArgs(args:Arguments, it:ListIterator, req:ListIterator, opt:ListIterator, req2:ListIterator):void
    #it.each do |arg|
    while it.hasNext
      arg = FormalArgument(it.next)
      name = arg.name
      next unless name.kind_of?(Unquote)
      next if arg.type # If the arg has a type then the unquote must only be an identifier.
      unquote = Unquote(name)
      new_args = unquote.arguments
      next unless new_args
      it.remove
      if it == req2 && new_args.optional.size == 0 && new_args.rest.nil? && new_args.required2.size == 0
        mergeIterators(new_args.required.listIterator, req2)
      else
        mergeIterators(new_args.required.listIterator, req)
        mergeIterators(new_args.optional.listIterator, opt)
        mergeIterators(new_args.required2.listIterator, req2)
      end
      if new_args.rest
        raise IllegalArgumentException, "Only one rest argument allowed." if args.rest
        rest = new_args.rest
        new_args.rest = nil
        args.rest = rest
      end
      if new_args.block
        raise IllegalArgumentException, "Only one block argument allowed" if args.block
        block = new_args.block
        new_args.block = nil
        args.block = block
      end
    end
  end

  def mergeIterators(source:ListIterator, dest:ListIterator):void
    #source.each do |a|
    while source.hasNext
      a = source.next
      source.remove
      dest.add(a)
    end
  end

  def mergeUnquotes(list:NodeList):void
    it = list.listIterator
    #it.each do |item|
    while it.hasNext
      item = it.next
      if item.kind_of?(Unquote)
        it.remove
        Unquote(item).nodes.each do |node|
          it.add(node)
        end
      end
    end
  end

  def visitRequiredArgument(arg, expression)
    scope = @scopes.getScope(arg)
    type = @types.getLocalType(scope, arg.name.identifier, arg.position)
    if arg.type
      type.declare(@types.get(scope, arg.type.typeref), arg.type.position)
    else
      type
    end
  end

  def visitOptionalArgument(arg, expression)
    scope = @scopes.getScope(arg)
    type = @types.getLocalType(scope, arg.name.identifier, arg.position)
    type.declare(@types.get(scope, arg.type.typeref), arg.type.position) if arg.type
    type.assign(infer(arg.value), arg.value.position)
    type
  end

  def visitRestArgument(arg, expression)
    scope = @scopes.getScope(arg)
    type = @types.getLocalType(scope, arg.name.identifier, arg.position)
    if arg.type
      type.declare(@types.getArrayType(@types.get(scope, arg.type.typeref)), arg.type.position)
    else
      type
    end
  end

  def visitBlockArgument(arg, expression)
    scope = @scopes.getScope(arg)
    type = @types.getLocalType(scope, arg.name.identifier, arg.position)
    if arg.type
      type.declare(@types.get(scope, arg.type.typeref), arg.type.position)
    else
      type
    end
  end

  def visitMethodDefinition(mdef, expression)
    @@log.entering("Typer", "visitMethodDefinition", mdef)
    # TODO optional arguments
    scope = @scopes.addScope(mdef)
    outer_scope = @scopes.getScope(mdef)
    selfType = outer_scope.selfType
    if mdef.kind_of?(StaticMethodDefinition)
      selfType = @types.getMetaType(selfType)
    end
    scope.selfType = selfType
    scope.resetDefaultSelfNode
    inferAll(mdef.annotations)
    infer(mdef.arguments)
    parameters = inferAll(mdef.arguments)
    type = @types.getMethodDefType(selfType, mdef.name.identifier, parameters)
    declareOptionalMethods(selfType, mdef, parameters, type.returnType)
    is_void = false
    if mdef.type
      returnType = @types.get(outer_scope, mdef.type.typeref)
      type.returnType.declare(returnType, mdef.type.position)
      if @types.getVoidType().resolve.equals(returnType.resolve)
        is_void = true
      end
    end
    # TODO deal with overridden methods?
    # TODO throws
    # mdef.exceptions.each {|e| type.throws(@types.get(TypeName(e).typeref))}
    if is_void
      infer(mdef.body, false)
      type.returnType.assign(@types.getVoidType, mdef.position)
    else
      type.returnType.assign(infer(mdef.body), mdef.body.position)
    end
  end
  
  def declareOptionalMethods(target:TypeFuture, mdef:MethodDefinition, argTypes:List, type:TypeFuture):void
    if mdef.arguments.optional_size > 0
      args = ArrayList.new(argTypes)
      first_optional_arg = mdef.arguments.required_size
      last_optional_arg = first_optional_arg + mdef.arguments.optional_size - 1
      last_optional_arg.downto(first_optional_arg) do |i|
        args.remove(i)
        @types.getMethodDefType(target, mdef.name.identifier, args).returnType.declare(type, mdef.position)
      end
    end
  end

  def visitStaticMethodDefinition(mdef, expression)
    visitMethodDefinition(mdef, expression)
  end

  def visitConstructorDefinition(mdef, expression)
    visitMethodDefinition(mdef, expression)
  end

  def visitImplicitNil(node, expression)
    @types.getImplicitNilType()
  end

  def visitImplicitSelf(node, expression)
    @scopes.getScope(node).selfType
  end

  # TODO is a constructor special?

  def visitBlock(block, expression)
    new_scope = @scopes.addScope(block)
    infer(block.arguments) if block.arguments
    closures = @closures
    parent = CallSite(block.parent)
    typer = self
    BlockFuture.new(block) do |x, resolvedType|
      unless resolvedType.isError
        # TODO: This will fail if the block's class changes.
        new_node = closures.prepare(block, resolvedType)
        if block == parent.block
          parent.block = nil
          parent.parameters.add(new_node)
        else
          new_node.setParent(nil)
          parent.replaceChild(block, new_node)
        end
        typer.infer(new_node)
      end
    end
  end

  def visitBindingReference(ref, expression)
    binding = @scopes.getScope(ref).binding_type
    future = BaseTypeFuture.new
    future.resolved(binding)
    future
  end

  def visitMacroDefinition(defn, expression)
    @macros.buildExtension(defn)
    #defn.parent.removeChild(defn)
    @types.getVoidType()
  end

  # Look for special blocks in the loop body and move them into the loop node.
  def enhanceLoop(node:Loop):void
    it = node.body.listIterator
    while it.hasNext
      child = it.next
      if child.kind_of?(FunctionalCall)
        call = FunctionalCall(child)
        name = call.name.identifier rescue nil
        if name.nil? || call.parameters_size() != 0 || call.block.nil?
          return
        end
        target_list = if name.equals("init")
          node.init
        elsif name.equals("pre")
          node.pre
        elsif name.equals("post")
          node.post
        else
          NodeList(nil)
        end
        if target_list
          it.remove
          target_list.add(call.block.body)
        else
          return
          nil
        end
      else
        return
        nil
      end
    end
  end
end
