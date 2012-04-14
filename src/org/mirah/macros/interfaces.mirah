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

package org.mirah.macros

import java.util.Map
import java.util.List
import mirah.lang.ast.Node
import mirah.lang.ast.Script
import org.mirah.typer.Scope

interface Macro do
  def expand:Node; end
end

interface Compiler do
  def serializeAst(node:Node):Object; end
  def deserializeAst(filename:String,
                     startLine:int,
                     startCol:int,
                     code:String,
                     values:List,
                     scope:Scope):Node
  end
end

interface JvmBackend do
  def compileAndLoadExtension(macro:Script):Class; end
  def logExtensionAst(node:Node):void; end
end