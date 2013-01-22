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
import mirah.lang.ast.*

interface TypeSystem do
  def getNullType:TypeFuture; end
  def getVoidType:TypeFuture; end
  def getImplicitNilType:TypeFuture; end

  # Used to determine which raise syntax is being used:
  #  - Single arg, assignable from getBaseExceptionType = exception object
  #  - 1+ args, first is a class assignable from getBaseExceptionType = Call constructor
  #  - else, create an exception of getDefaultExceptionType.
  def getBaseExceptionType:TypeFuture; end

  # The default exceptiont type caught by rescue statements and raised by raise statements.
  def getDefaultExceptionType:TypeFuture; end

  def getRegexType:TypeFuture; end
  def getStringType:TypeFuture; end
  def getHashType:TypeFuture; end
  def getBooleanType:TypeFuture; end

  # TODO: These should take a position
  def getFixnumType(value:long):TypeFuture; end
  def getCharType(value:int):TypeFuture; end
  def getFloatType(value:double):TypeFuture; end

  def getBlockType:ResolvedType; end

  # Returns the meta type of a type.
  # The meta type contains the static methods.
  def getMetaType(type:ResolvedType):ResolvedType; end

  # Returns the type for an array of componentType.
  def getArrayType(componentType:ResolvedType):ResolvedType; end

  # Similar, but with futures.
  def getMetaType(type:TypeFuture):TypeFuture; end
  def getArrayType(componentType:TypeFuture):TypeFuture; end

  # Returns a future for the type of an array literal: [ 1, 2, 3]
  def getArrayLiteralType(componentType:TypeFuture, position:Position):TypeFuture; end

  # Returns a future for the type of a hash literal: {a: b}
  def getHashLiteralType(keyType:TypeFuture, valueType:TypeFuture, position:Position):TypeFuture; end

  # Convert a TypeRef to a TypeFuture.
  def get(scope:Scope, type:TypeRef):TypeFuture; end

  # Returns a future for a method call. Must resolve to a MethodType or an error.
  # TODO scope
  def getMethodType(call:CallFuture):TypeFuture; end

  #def getMethodType(target:ResolvedType, name:String, argTypes:List, position:Position):TypeFuture; end

  # Returns the MethodFuture for a method definition.
  # argTypes is a list of TypeFutures
  # returnType is nil if there is no declared return type
  def getMethodDefType(target:TypeFuture,
                       name:String,
                       argTypes:List,
                       returnType:TypeFuture,
                       position:Position):MethodFuture; end

  def getFieldType(target:TypeFuture, name:String, position:Position):AssignableTypeFuture; end

  def getLocalType(scope:Scope, name:String, position:Position):AssignableTypeFuture; end

  # Returns a future for the default class in a Script.
  def getMainType(scope:Scope, script:Script):TypeFuture; end

  def getSuperClass(type:TypeFuture):TypeFuture; end

  # Called by the Typer to inform the TypeSystem of a newly defined class.
  def defineType(scope:Scope, node:ClassDefinition, name:String, superclass:TypeFuture, interfaces:List):TypeFuture; end

  # Initializes the imports for a Script node.
  def addDefaultImports(scope:Scope):void; end

  # Returns a List of MethodTypes of the abstract methods that a closure should implement.
  def getAbstractMethods(type:ResolvedType):List; end

  # Adds a macro to a class.
  # macro must implement org.mirah.macros.Macro
  def addMacro(klass:ResolvedType, macro:Class):void; end

  # Adds all of the macros defined in extensions to klassname.
  # klassname must be fully qualified.
  def extendClass(klassname:String, extensions:Class):void; end
end
