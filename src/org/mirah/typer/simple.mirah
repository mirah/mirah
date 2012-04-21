# These are minimal implementations of the type system interfaces.
# These are used for tests and may also be useful as building blocks
# for a full type system.
# The main type system implementation is in lib/mirah/jvm/types/factory.rb.
package org.mirah.typer.simple

import java.util.*
import org.mirah.typer.*
import mirah.lang.ast.NodeScanner
import mirah.lang.ast.Node
import mirah.lang.ast.Position
import mirah.impl.MirahParser
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.FileInputStream
import java.io.PrintStream

class ListWrapper < AbstractList
  def initialize(list:List)
    @list = list
  end
  def size
    @list.size
  end
  def get(i)
    @list.get(i)
  end
end

class SimpleType < SpecialType
  def initialize(name:String, meta=false, array=false)
    super(name)
    @meta = meta
    @array = array
  end

  def widen(other)
    return self if other.matchesAnything
    return ErrorType.new([["Incompatible types"]]) unless equals(other)
    self
  end
  def assignableFrom(other)
    matchesAnything || other.matchesAnything || equals(other)
  end
  def isMeta
    @meta
  end
  def isArray
    @array
  end
  def toString
    "<#{isMeta ? 'Meta' : ''}Type #{name}#{isArray ? '[]' : ''}>"
  end
  def equals(other)
    return false if other.nil?
    toString.equals(other.toString)
  end
  def hashCode
    toString.hashCode
  end
end

class SimpleTypes; implements TypeSystem
  def initialize(main_type:String)
    @types = {}
    [ :Null, :Void, :Exception, :Regex,
      :String, :Bool, :Int, :Char, :Float,
      :Hash, 'mirah.impl.Builtin'
      ].each { |t| @types[t] = SimpleType.new(String(t), false, false)}
    @meta_types = {}
    @array_types = {}
    @fields = {}
    @locals = {}
    @types[main_type] = @main_type = SimpleType.new(main_type, false, false)
  end
  def lookup(name:String)
    TypeFuture(@types[name])
  end
  def getNullType
    lookup :Null
  end
  def getImplicitNilType
    getNullType
  end
  def getVoidType
    lookup :Void
  end
  def getBaseExceptionType
    lookup :Exception
  end
  def getDefaultExceptionType
    lookup :Exception
  end
  def getRegexType
    lookup :Regex
  end
  def getStringType
    lookup :String
  end
  def getBooleanType
    lookup :Bool
  end
  def getFixnumType(value)
    lookup :Int
  end
  def getCharType(value)
    lookup :Char
  end
  def getFloatType(value)
    lookup :Float
  end
  def getHashType
    lookup :Hash
  end

  def getMetaType(type:ResolvedType)
    return type if type.isMeta
    t = ResolvedType(@meta_types[type])
    unless t
      t = ResolvedType(SimpleType.new(type.name, true, false))
      @meta_types[type] = t
    end
    t
  end
  def getMetaType(type:TypeFuture)
    TypeFuture(getMetaType(ResolvedType(type)))
  end
  def getArrayType(componentType:ResolvedType)
    # What about multi-dimensional arrays?
    t = ResolvedType(@array_types[componentType])
    unless t
      t = ResolvedType(SimpleType.new(componentType.name, false, true))
      @array_types[componentType] = t
    end
    t
  end
  def getArrayType(componentType:TypeFuture)
    TypeFuture(getArrayType(componentType.resolve))
  end
  def get(scope, typeref)
    raise IllegalArgumentException if typeref.nil?
    basic_type = lookup(typeref.name) || SimpleType.new(typeref.name, false, false)
    return getMetaType(basic_type) if typeref.isStatic
    return getArrayType(basic_type) if typeref.isArray
    return basic_type
  end
  def getMethodType(call)
    target = call.resolved_target
    argTypes = call.resolved_parameters
    raise IllegalArgumentException if target.nil?
    raise IllegalArgumentException unless argTypes.all?
    getMethodTypeInternal(target, call.name, argTypes, call.position)
  end
  def getMethodDefType(target, name, argTypes)
    args = ArrayList.new(argTypes.size)
    argTypes.size.times do |i|
      resolved = TypeFuture(argTypes.get(i)).resolve
      args.add(i, resolved)
    end
    getMethodTypeInternal(target.resolve, name, args, nil)
  end
  
  def getMethodTypeInternal(target:ResolvedType, name:String, argTypes:List, position:Position):MethodFuture
    if argTypes.kind_of?(org::jruby::RubyArray)
      # RubyArray claims to implement List, but it doesn't have the right
      # implementation of equals or hashCode.
      argTypes = ListWrapper.new(argTypes)
    end
    # Start with an error message in case it isn't found.
    return_type = AssignableTypeFuture.new(nil).resolved(ErrorType.new([
        ["Cannot find method #{target}.#{name}#{argTypes}", position]]))
    MethodFuture.new(name, argTypes, return_type, false, position)
  end
  
  def getFieldType(target, name, position)
    key = [target.resolve, name]
    t = AssignableTypeFuture(@fields[key])
    unless t
      t = AssignableTypeFuture.new(position)
      @fields[key] = t
    end
    t
  end
  def getLocalType(scope, name, position)
    key = [scope, name]
    t = AssignableTypeFuture(@locals[key])
    unless t
      t = AssignableTypeFuture.new(position)
      @locals[key] = t
    end
    t
  end
  def getMainType(scope, script)
    @main_type
  end
  def getSuperClass(type)
    nil
  end
  def defineType(scope, node, name, superclass, interfaces)
    type = lookup(name)
    unless type
      type = SimpleType.new(name, false, false)
      @types[name] = type
    end
    type
  end
  def addDefaultImports(scope)
  end

  def self.main(args:String[]):void
    parser = MirahParser.new
    code = StringBuilder.new
    reader = BufferedReader.new(InputStreamReader.new(FileInputStream.new(args[0])))
    buffer = char[8192]
    while (read = reader.read(buffer, 0, buffer.length)) > 0
      code.append(buffer, 0, read);
    end

    ast = Node(parser.parse(code.toString))
    types = SimpleTypes.new('foo')
    scopes = SimpleScoper.new
    typer = Typer.new(types, scopes, nil)

    puts "Original AST:"
    TypePrinter.new(typer).scan(ast, nil)
    puts
    puts "Inferring types..."

    typer.infer(ast, false)

    TypePrinter.new(typer).scan(ast, nil)
  end
end

class SimpleScope; implements Scope
  def initialize
    @nextTemp = -1
  end
  def context:Node
    @node
  end
  def context=(node:Node):void
    @node = node
  end
  def selfType:TypeFuture
    @selfType || (@parent && @parent.selfType)
  end
  def selfType=(type:TypeFuture):void
    @selfType = type
  end
  def parent:Scope
    @parent
  end
  def parent=(scope:Scope):void
    @parent = scope
  end
  def import(fullname:String, shortname:String)
  end
  def package:String
    @package
  end
  def package=(p:String)
    @package = p
  end
  def temp(name)
    "#{name}#{@nextTemp += 1}"
  end
  def shadow(name:String):void; end
  def resetDefaultSelfNode:void; end
end

interface ScopeFactory do
  def newScope(scoper:Scoper, node:Node):Scope; end
end

class SimpleScoper; implements Scoper
  def initialize
    @scopes = {}
  end
  def initialize(factory:ScopeFactory)
    @factory = factory
    @scopes = {}
  end
  def getScope(node)
    orig = node
    until node.parent.nil?
      node = node.parent
      scope = Scope(@scopes[node])
      return scope if scope
    end
    Scope(@scopes[node]) || addScope(node)
  end
  def getIntroducedScope(node:Node)
    Scope(@scopes[node])
  end
  def addScope(node)
    scope = if @factory
      @factory.newScope(self, node)
    else
      SimpleScope.new
    end
    @scopes[node] = scope
    scope
  end
  def copyScopeFrom(from, to)
    @scopes[to] = getScope(from)
  end
end

class TypePrinter < NodeScanner
  def initialize(typer:Typer)
    initialize(typer, System.out)
  end
  
  def initialize(typer:Typer, writer:PrintStream)
    @indent = 0
    @typer = typer
    @args = Object[1]
    @args[0] = ""
    @out = writer
  end
  def printIndent:void
    @out.printf("%#{@indent}s", @args) if @indent > 0
  end
  def enterDefault(node, arg)
    printIndent
    @out.print(node)
    type = @typer.getInferredType(node)
    if type
      @out.print ": #{type.resolve}"
    end
    @out.println
    @indent += 2
    true
  end
  def enterUnquote(node, arg)
    super(node, arg)
    if node.object
      if node.object.kind_of?(Node)
        Node(node.object).accept(self, arg)
      else
        printIndent
        @out.print node.object
        @out.println
      end
    end
    node.object.nil?
  end
  def exitDefault(node, arg)
    @indent -= 2
    nil
  end
end
