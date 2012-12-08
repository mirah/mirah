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

package org.mirah.typer.simple

import java.util.*
import org.mirah.typer.*
import mirah.lang.ast.NodeScanner
import mirah.lang.ast.Node
import mirah.lang.ast.Position
import mirah.lang.ast.StreamCodeSource
import mirah.impl.MirahParser
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.FileInputStream
import java.io.PrintStream

# A minimal TypeSystem for the Typer tests.
# The main TypeSystem is Mirah::JVM::Types::TypeFactory, in
# lib/mirah/jvm/types/factory.rb
class SimpleTypes; implements TypeSystem
  def initialize(main_type:String)
    @types = {}
    [ :Null, :Void, :Exception, :Regex,
      :String, :Bool, :Int, :Char, :Float,
      :Hash, 'mirah.impl.Builtin'
      ].each { |t| @types[t] = SimpleType.new(String(t), false, false)}
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
    unless argTypes.all?
      error = BaseTypeFuture.new(call.position)
      error.resolved(ErrorType.new([["Unresolved args", call.position]]))
      return error
    end
    getMethodTypeInternal(target, call.name, argTypes, call.position)
  end
  def getMethodDefType(target, name, argTypes, returnType, position)
    args = ArrayList.new(argTypes.size)
    argTypes.size.times do |i|
      resolved = TypeFuture(argTypes.get(i)).resolve
      args.add(i, resolved)
    end
    result = getMethodTypeInternal(target.resolve, name, args, position)
    result.returnType.declare(returnType, position) if returnType
    result
  end

  def getMethodTypeInternal(target:ResolvedType, name:String, argTypes:List, position:Position):MethodFuture
    if argTypes.getClass.getName.equals("org.jruby.RubyArray")
      # RubyArray claims to implement List, but it doesn't have the right
      # implementation of equals or hashCode.
      argTypes = ListWrapper.new(argTypes)
    end

    key = [target, name, argTypes]
    t = MethodFuture(@methods[key])
    unless t
      # Start with an error message in case it isn't found.
      return_type = AssignableTypeFuture.new(nil).resolved(ErrorType.new([
          ["Cannot find method #{target}.#{name}#{argTypes}", position]]))
      t = MethodFuture.new(name, argTypes, return_type, false, position)
      @methods[key] = t
    end
    t
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
end

logger = org::mirah::MirahLogFormatter.new(true).install
logger.setLevel(java::util::logging::Level.ALL)
parser = MirahParser.new
code = StreamCodeSource.new("stdin", System.in)

ast = Node(parser.parse(code))
types = SimpleTypes.new('foo')
scopes = SimpleScoper.new
typer = Typer.new(types, scopes, nil)

puts "Original AST:"
TypePrinter.new(typer).scan(ast, nil)
puts
puts "Inferring types..."

typer.infer(ast, false)

TypePrinter.new(typer).scan(ast, nil)
