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
import mirah.lang.ast.Call
import mirah.lang.ast.Cast
import mirah.lang.ast.FieldAccess
import mirah.lang.ast.Node
import mirah.lang.ast.Script
import mirah.lang.ast.SimpleString
import mirah.lang.ast.Unquote
import org.mirah.macros.anno.*
import org.mirah.typer.Scope


$Extensions[macros:['org.mirah.macros.QuoteMacro']]
interface Macro do
  def expand:Node; end
end

$Extensions[macros:['org.mirah.macros.QuoteMacro']]
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

# The bootstrap compiler can't generate newast macros, so we manually implement quote
$MacroDef[name:'quote', signature:'(Lmirah.lang.ast.Block;)V']
class QuoteMacro; implements Macro
  def initialize(mirah:Compiler, call:Call)
    @mirah = mirah
    @call = call
  end
  
  def expand
    node = if @call.block.body_size == 1
      @call.block.body(0)
    else
      @call.block.body
    end
    serialized = @mirah.serializeAst(node)
    unquote = Unquote.new
    unquote.object = serialized
    loadCall = Call.new(FieldAccess.new(SimpleString.new("mirah")), SimpleString.new("deserializeAst"), [unquote], nil)
    Cast.new(SimpleString.new(node.getClass.getName), loadCall)
  end
end