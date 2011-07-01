package org.mirah.typer.simple

import java.util.*
import org.mirah.typer.*
import mirah.lang.ast.NodeScanner
import mirah.lang.ast.Node
import mirah.impl.MirahParser
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.FileInputStream

class SimpleType < SpecialType
  def initialize(name:String, meta=false, array=false)
    super(name)
    @meta = meta
    @array = array
  end

  def widen(other)
    return other if other.isError
    return self if ":unreachable".equals(other.name)
    return ErrorType.new([["Incompatible types"]]) unless equals(other)
    self
  end
  def assignableFrom(other)
    other.isError || ":unreachable".equals(other.name) || equals(other)
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
    [ :null, :void, :exception, :regex,
      :string, :bool, :int, :char, :float].each { |t| @types[t] = SimpleType.new(String(t), false, false)}
    @meta_types = {}
    @array_types = {}
    @methods = {}
    @fields = {}
    @locals = {}
    @types[main_type] = @main_type = SimpleType.new(main_type, false, false)
  end
  def lookup(name:String)
    TypeFuture(@types[name])
  end
  def getNullType
    lookup :null
  end
  def getVoidType
    lookup :void
  end
  def getBaseExceptionType
    lookup :exception
  end
  def getDefaultExceptionType
    lookup :exception
  end
  def getRegexType
    lookup :regex
  end
  def getStringType
    lookup :string
  end
  def getBooleanType
    lookup :bool
  end
  def getFixnumType(value)
    lookup :int
  end
  def getCharType(value)
    lookup :char
  end
  def getFloatType(value)
    lookup :float
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
    TypeFuture(getArrayType(ResolvedType(componentType)))
  end
  def get(typeref)
    basic_type = lookup(typeref.name) || SimpleType.new(typeref.name, false, false)
    return getMetaType(basic_type) if typeref.isStatic
    return getArrayType(basic_type) if typeref.isArray
    return basic_type
  end
  def getMethodType(target, name, argTypes)
    key = [target, name, argTypes]
    t = TypeFuture(@methods[key])
    unless t
      t = AssignableTypeFuture.new(nil)
      @methods[key] = t
    end
    t
  end
  def getMethodDefType(target, name, argTypes)
    args = ArrayList.new(argTypes.size)
    argTypes.size.times do |i|
      resolved = TypeFuture(argTypes.get(i)).resolve
      args.set(i, resolved)
    end
    AssignableTypeFuture(getMethodType(target.resolve, name, args))
  end
  def getFieldType(target, name)
    key = [target.resolve, name]
    t = AssignableTypeFuture(@fields[key])
    unless t
      t = AssignableTypeFuture.new(nil)
      @fields[key] = t
    end
    t
  end
  def getLocalType(scope, name)
    key = [scope, name]
    t = AssignableTypeFuture(@locals[key])
    unless t
      t = AssignableTypeFuture.new(nil)
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

  def self.main(args:String[]):void
    parser = MirahParser.new
    code = StringBuilder.new
    reader = BufferedReader.new(InputStreamReader.new(FileInputStream.new(args[0])))
    while line = reader.readLine
      code.append(line)
    end
    ast = Node(parser.parse(code.toString))
    types = SimpleTypes.new('foo')
    scopes = SimpleScoper.new
    typer = Typer.new(types, scopes)
    typer.infer(ast, false)
    TypePrinter.new(typer).scan(ast, nil)
  end
end

class SimpleScope; implements Scope
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
  def shadow(name:String):void; end
  def resetDefaultSelfNode:void; end
end

class SimpleScoper; implements Scoper
  def initialize
    @scopes = {}
  end
  def getScope(node)
    until node.parent.nil?
      node = node.parent
      scope = Scope(@scopes[node])
      puts "Found scope #{scope} for #{node}"
      return scope if scope
    end
    Scope(@scopes[node]) || addScope(node)
  end
  def addScope(node)
    scope = SimpleScope.new
    @scopes[node] = scope
    puts "Added scope #{scope} for #{node}"
    scope
  end
end

class TypePrinter < NodeScanner
  def initialize(typer:Typer)
    @indent = 0
    @typer = typer
    @args = Object[1]
    @args[0] = ""
  end
  def printIndent:void
    System.out.printf("%#{@indent}s", @args)
  end
  def enterDefault(node, arg)
    printIndent
    print node
    type = @typer.getInferredType(node)
    if type
      print ": #{type}"
    end
    puts
    @indent += 2
    true
  end
  def exitDefault(node, arg)
    @indent -= 1
    nil
  end
end