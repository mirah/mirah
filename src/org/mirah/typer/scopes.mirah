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
import java.util.List
import java.util.Map

interface Scope do
  def selfType:TypeFuture; end  # Should this be resolved?
  def selfType=(type:TypeFuture):void; end
  def context:Node; end
  def parent:Scope; end
  def parent=(scope:Scope):void; end
  def shadow(name:String):void; end
  def isCaptured(name:String):boolean; end
  def capturedLocals:List; end  # List of captured local variable names
  def import(fullname:String, shortname:String); end
  def staticImport(type:TypeFuture):void; end
  def package:String; end
  def package=(package:String):void; end
  def resetDefaultSelfNode:void; end
  def temp(name:String):String; end
  def imports:Map; end  # Map of short -> long; probably should be reversed.
  def search_packages:List; end
  def binding_type:ResolvedType; end
  def binding_type=(type:ResolvedType); end
end

interface Scoper do
  def getScope(node:Node):Scope; end
  def addScope(node:Node):Scope; end
  def getIntroducedScope(node:Node):Scope; end
  def copyScopeFrom(from:Node, to:Node):void; end
end
