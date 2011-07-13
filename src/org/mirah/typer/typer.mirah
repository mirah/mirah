package org.mirah.typer
import java.util.*
import mirah.lang.ast.*

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
  def initialize(types:TypeSystem, scopes:Scoper)
    @trueobj = java::lang::Boolean.valueOf(true)
    @futures = HashMap.new
    @types = types
    @scopes = scopes
  end

  def getInferredType(node:Node)
    TypeFuture(@futures[node])
  end

  def infer(node:Node, expression:boolean=true)
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

  def inferAll(typeNames:TypeNameList)
    types = ArrayList.new
    typeNames.each {|n| types.add(@types.get(TypeName(n).typeref))}
    types
  end

  def defaultNode(node, expression)
    ErrorType.new(["Inference error", node.position])
  end

  def visitVCall(call, expression)
    selfType = @scopes.getScope(call).selfType
    methodType = CallFuture.new(call.position, @types, selfType, call.name.identifier, Collections.emptyList)
    typer = self
    methodType.onUpdate do |x, resolvedType|
      if resolvedType.kind_of?(InlineCode)
        node = InlineCode(resolvedType).node
        call.parent.replaceChild(call, node)
        typer.infer(node, expression != nil)
      end
    end

    # This might actually be a local access instead of a method call,
    # so try both. If the local works, we'll go with that. If not, we'll
    # leave the method call.
    # TODO should probably replace this with a FunctionalCall node if that's the
    # right one so the compiler doesn't have to deal with an extra node.
    local = LocalAccess.new(call.position, call.name)
    localType = @types.getLocalType(@scopes.getScope(call), local.name.identifier)
    @futures[local] = localType
    TypeFuture(MaybeInline.new(call, methodType, local, localType))
  end

  def visitFunctionalCall(call, expression)
    selfType = @scopes.getScope(call).selfType
    mergeUnquotes(call.parameters)
    parameters = inferAll(call.parameters)
    parameters.add(BlockType.new) if call.block
    methodType = CallFuture.new(call.position, @types, selfType, call.name.identifier, parameters)
    typer = self
    methodType.onUpdate do |x, resolvedType|
      if resolvedType.kind_of?(InlineCode)
        node = InlineCode(resolvedType).node
        call.parent.replaceChild(call, node)
        typer.infer(node, expression != nil)
      end
    end
    if parameters.size == 1
      # This might actually be a cast instead of a method call, so try
      # both. If the cast works, we'll go with that. If not, we'll leave
      # the method call.
      cast = Cast.new(call.position, TypeName(call.typeref), Node(call.parameters.get(0).clone))
      castType = @types.get(call.typeref)
      @futures[cast] = castType
      TypeFuture(MaybeInline.new(call, methodType, cast, castType))
    else
      methodType
    end
  end

  def visitCall(call, expression)
    target = infer(call.target)
    mergeUnquotes(call.parameters)
    parameters = inferAll(call.parameters)
    parameters.add(BlockType.new) if call.block
    methodType = CallFuture.new(call.position, @types, target, call.name.identifier, parameters)
    typer = self
    methodType.onUpdate do |x, resolvedType|
      if resolvedType.kind_of?(InlineCode)
        node = InlineCode(resolvedType).node
        call.parent.replaceChild(call, node)
        typer.infer(node, expression != nil)
      end
    end
    if  parameters.size == 1
      # This might actually be a cast instead of a method call, so try
      # both. If the cast works, we'll go with that. If not, we'll leave
      # the method call.
      typeref = call.typeref(true)
      if typeref
        cast = Cast.new(call.position, TypeName(typeref), Node(call.parameters.get(0).clone))
        castType = @types.get(typeref)
        @futures[cast] = castType
        TypeFuture(MaybeInline.new(call, methodType, cast, castType))
      else
        methodType
      end
    else
      methodType
    end
  end

  def visitColon2(colon2, expression)
    @types.get(colon2.typeref)
  end

  def visitSuper(node, expression)
    method = MethodDefinition(node.findAncestor(MethodDefinition.class))
    target = @types.getSuperClass(@scopes.getScope(node).selfType)
    parameters = inferAll(node.parameters)
    parameters.add(BlockType.new) if node.block
    CallFuture.new(node.position, @types, target, method.name.identifier, parameters)
  end

  def visitZSuper(node, expression)
    method = MethodDefinition(node.findAncestor(MethodDefinition.class))
    target = @types.getSuperClass(@scopes.getScope(node).selfType)
    parameters = inferAll(method.arguments)
    CallFuture.new(node.position, @types, target, method.name.identifier, parameters)
  end

  def visitClassDefinition(classdef, expression)
    classdef.annotations.each {|a| infer(a)}
    interfaces = inferAll(classdef.interfaces)
    superclass = @types.get(classdef.superclass.typeref) if classdef.superclass
    type = @types.defineType(@scopes.getScope(classdef), classdef, classdef.name.identifier, superclass, interfaces)
    scope = @scopes.addScope(classdef)
    scope.selfType = type
    infer(classdef.body, false) if classdef.body
    type
  end

  def visitFieldDeclaration(decl, expression)
    decl.annotations.each {|a| infer(a)}
    targetType = @scopes.getScope(decl).selfType
    targetType = @types.getMetaType(targetType) if decl.isStatic
    @types.getFieldType(targetType, decl.name.identifier).declare(@types.get(decl.type.typeref), decl.position)
  end

  def visitFieldAssign(field, expression)
    field.annotations.each {|a| infer(a)}
    targetType = @scopes.getScope(field).selfType
    targetType = @types.getMetaType(targetType) if field.isStatic
    value = infer(field.value, true)
    @types.getFieldType(targetType, field.name.identifier).assign(value, field.position)
  end

  def visitFieldAccess(field, expression)
    targetType = @scopes.getScope(field).selfType
    targetType = @types.getMetaType(targetType) if field.isStatic
    @types.getFieldType(targetType, field.name.identifier)
  end

  def visitConstant(constant, expression)
    @types.get(constant.typeref)
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
    @types.getMethodDefType(target, method.name.identifier, parameters).assign(type, node.position)
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
      exceptions.add(infer(old_args.get(0)))
      exceptions.add(Node(old_args.get(0)).clone)
    end

    # Create a node for syntax 2 if possible.
    if old_args.size > 0
      targetNode = Node(Node(old_args.get(0)).clone)
      params = ArrayList.new
      1.upto(old_args.size - 1) {|i| params.add(Node(old_args.get(i)).clone)}
      call = Call.new(targetNode, SimpleString.new(node.position, 'new'), params, nil)
      exceptions.add(infer(call))
      exceptions.add(call)
    end

    # Create a node for syntax 3.
    class_name = @types.getDefaultExceptionType().resolve.name
    targetNode = Constant.new(node.position, SimpleString.new(node.position, class_name))
    params = ArrayList.new
    old_args.each {|a| params.add(Node(a).clone)}
    call = Call.new(node.position, targetNode, SimpleString.new(node.position, 'new'), params, nil)
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
    if name
      scope.shadow(name.identifier)
      exceptionType = @types.getLocalType(scope, name.identifier)
      clause.types.each do |_t|
        t = TypeName(_t)
        exceptionType.assign(@types.get(t.typeref), t.position)
      end
    else
      inferAll(clause.types)
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
    @types.getArrayType(component)
  end

  def visitFixnum(fixnum, expression)
    @types.getFixnumType(fixnum.value)
  end

  def visitFloat(number, expression)
    @types.getFloatType(number.value)
  end

  def visitHash(hash, expression)
    target = TypeRefImpl.new('mirah.impl.Builtin', false, true, hash.position)
    call = Call.new(target, SimpleString.new('new_hash'), nil, nil)
    hash.parent.replaceChild(hash, call)
    call.parameters.add(hash)
    infer(call, expression != nil)
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

  # What about ImplicitNil? Should it be void? null?

  def visitCharLiteral(node, expression)
    @types.getCharType(node.value)
  end

  def visitSelf(node, expression)
    @scopes.getScope(node).selfType
  end

  def visitTypeRefImpl(typeref, expression)
    @types.get(typeref)
  end

  def visitLocalDeclaration(decl, expression)
    type = @types.get(decl.type.typeref)
    @types.getLocalType(@scopes.getScope(decl), decl.name.identifier).declare(type, decl.position)
  end

  def visitLocalAssignment(local, expression)
    value = infer(local.value, true)
    @types.getLocalType(@scopes.getScope(local), local.name.identifier).assign(value, local.position)
  end

  def visitLocalAccess(local, expression)
    @types.getLocalType(@scopes.getScope(local), local.name.identifier)
  end

  def visitNodeList(body, expression)
    (body.size - 1).times do |i|
      infer(body.get(i), false)
    end
    if body.size > 0
      infer(body.get(body.size - 1), expression != null)
    else
      # TODO getImplicitNilType()? getVoidType()?
      @types.getNullType()
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
    scope.selfType = @types.getMainType(scope, script)
    infer(script.body, false)
  end

  def visitAnnotation(anno, expression)
    anno.values_size.times do |i|
      infer(anno.values(i).value)
    end
    @types.get(anno.type.typeref)
  end

  def visitImport(node, expression)
    scope = @scopes.getScope(node)
    fullName = node.fullName.identifier
    simpleName = node.simpleName.identifier
    scope.import(fullName, simpleName)
    unless '*'.equals(simpleName)
      @types.get(TypeName(node.fullName).typeref)
    end
    @types.getVoidType()
  end

  def visitPackage(node, expression)
    if node.body
      scope = @scopes.addScope(node)
      scope.parent = @scopes.getScope(node)
      infer(node.body, false)
    else
      scope = @scopes.getScope(node)
    end
    scope.package = node.name.identifier
    @types.getVoidType()
  end

  def visitEmptyArray(node, expression)
    infer(node.size)
    @types.getArrayType(@types.get(node.type.typeref))
  end

  def visitUnquote(node, expression)
    node.nodes.each {|n| infer(n, expression != nil)}
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
    node.parent.replaceChild(node, replacement)
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
      arg = Named(it.next)
      name = arg.name
      next unless name.kind_of?(Unquote)
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
    type = @types.getLocalType(scope, arg.name.identifier)
    if arg.type
      type.declare(@types.get(arg.type.typeref), arg.type.position)
    else
      type
    end
  end

  def visitOptionalArgument(arg, expression)
    scope = @scopes.getScope(arg)
    type = @types.getLocalType(scope, arg.name.identifier)
    type.declare(@types.get(arg.type.typeref), arg.type.position) if arg.type
    type.assign(infer(arg.value), arg.value.position)
  end

  def visitRestArgument(arg, expression)
    scope = @scopes.getScope(arg)
    type = @types.getLocalType(scope, arg.name.identifier)
    if arg.type
      type.declare(@types.getArrayType(@types.get(arg.type.typeref)), arg.type.position)
    else
      type
    end
  end

  def visitBlockArgument(arg, expression)
    scope = @scopes.getScope(arg)
    type = @types.getLocalType(scope, arg.name.identifier)
    if arg.type
      type.declare(@types.get(arg.type.typeref), arg.type.position)
    else
      type
    end
  end

  def visitMethodDefinition(mdef, expression)
    # TODO optional arguments
    scope = @scopes.addScope(mdef)
    selfType = @scopes.getScope(mdef).selfType
    if mdef.kind_of?(StaticMethodDefinition)
      selfType = @types.getMetaType(selfType)
    end
    scope.selfType = selfType
    scope.resetDefaultSelfNode
    inferAll(mdef.annotations)
    infer(mdef.arguments)
    parameters = inferAll(mdef.arguments)
    type = @types.getMethodDefType(selfType, mdef.name.identifier, parameters)
    is_void = false
    if mdef.type
      returnType = @types.get(mdef.type.typeref)
      type.declare(returnType, mdef.type.position)
      if @types.getVoidType().equals(returnType)
        is_void = true
      end
    end
    # TODO deal with overridden methods?
    # TODO throws
    # mdef.exceptions.each {|e| type.throws(@types.get(TypeName(e).typeref))}
    if is_void
      infer(mdef.body, false)
      type.assign(@types.getVoidType, mdef.position)
    else
      type.assign(infer(mdef.body), mdef.body.position)
    end
    type
  end

  def visitStaticMethodDefinition(mdef, expression)
    visitMethodDefinition(mdef, expression)
  end

  def visitImplicitNil(node, expression)
    @types.getNullType  # Should this be void?
  end

  # TODO is a constructor special?

  # TODO
  # def visitBlock(block, expression)
  # end
  # 
  # def visitMacroDefinition(defn, expression)
  #   buildAndLoadExtension(defn)
  #   defn.getParent.removeChild(defn)
  #   @types.getVoidType()
  # end
end