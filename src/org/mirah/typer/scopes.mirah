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

import mirah.lang.ast.Node
import mirah.lang.ast.Position

import java.util.List
import java.util.Map

interface Scope do
  def selfType: TypeFuture; end  # Should this be resolved?
  def selfType=(type: TypeFuture): void; end
  def context: Node; end
  def parent: Scope; end
  def parent=(scope: Scope): void; end
  def shadow(name: String): void; end
  def shadowed?(name: String):boolean; end
  def hasLocal(name: String, includeParent:boolean=true):boolean;end
  def isCaptured(name: String):boolean; end
  def capturedLocals: List; end  # List of captured local variable names
  def import(fullname: String, shortname: String): void; end
  # Wrapper around import() to make it accessible from java
  def add_import(fullname: String, shortname: String): void; end
  def staticImport(type: TypeFuture): void; end
  # package for this scope
  def package: String; end
  def package=(package: String): void; end
  # create a temp var for this scope with name
  def temp(name: String): String; end
  def imports: Map; end  # Map of short -> long; probably should be reversed.
  def search_packages: List; end
  # type of the binding for this scope, if it has one
  # this walks up parents to find the right one to attach to
  def binding_type: ResolvedType; end
  def binding_type=(type: ResolvedType): void; end
  # type of the binding for exactly this scope
  def declared_binding_type: ResolvedType; end
  def declared_binding_type=(type: ResolvedType): void; end

  def hasField(name: String, includeParent:boolean=true): boolean; end
  def fieldUsed(name: String): void; end
  def capturedFields(): List; end
  def isCapturedField(name: String): boolean; end

  def hasMethodCall(name: String, includeParent:boolean=true): boolean; end
  def methodUsed(name: String): void; end
  def capturedMethods(): List; end
  def isCapturedMethod(name: String): boolean; end


  def selfUsed(): void; end
  def capturedSelf: boolean; end
  def hasSelf: boolean; end

  def getLocalType(name: String, position: Position):LocalFuture; end
end

interface Scoper do
  # parent scope of node
  def getScope(node: Node): Scope; end
  # add scope to nodes below node
  def addScope(node: Node): Scope; end
  # get scope of node
  def getIntroducedScope(node: Node): Scope; end
  def copyScopeFrom(from: Node, to: Node): void; end
  def setScope(node: Node, scope: Scope): void; end 
end
