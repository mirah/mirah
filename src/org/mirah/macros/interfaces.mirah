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
import mirah.lang.ast.CallSite
import mirah.lang.ast.Cast
import mirah.lang.ast.FieldAccess
import mirah.lang.ast.Node
import mirah.lang.ast.Script
import mirah.lang.ast.SimpleString
import mirah.lang.ast.Unquote
import org.mirah.macros.anno.*
import org.mirah.typer.Scoper
import org.mirah.typer.Typer
import org.mirah.typer.TypeSystem


interface Macro do
  def expand:Node; end
  macro def quote(block:Block)
    node = if @call.block.body_size == 1
      @call.block.body(0)
    else
      @call.block.body
    end
    serialized = @mirah.serializeAst(node)
    cast = quote {Cast(@mirah.deserializeAst(`serialized`))}
    cast.name = SimpleString.new(node.getClass.getName)
    cast
  end
end

interface Compiler do
  def serializeAst(node:Node):Object; end
  def deserializeAst(filename:String,
                     startLine:int,
                     startCol:int,
                     code:String,
                     values:List):Node
  end
  def type_system:TypeSystem; end
  def typer:Typer; end
  def scoper:Scoper; end
  def cast(typename:Object, value:Object):Cast; end
  macro def quote(block:Block)
    node = if @call.block.body_size == 1
      @call.block.body(0)
    else
      @call.block.body
    end
    serialized = @mirah.serializeAst(node)
    cast = quote {Cast(`@call.target`.deserializeAst(`serialized`))}
    cast.name = SimpleString.new(node.getClass.getName)
    cast
  end
end

interface JvmBackend do
  def compileAndLoadExtension(macro:Script):Class; end
  def logExtensionAst(node:Node):void; end
end

interface ExtensionsService
    # @param - macro_holder - a class holding ExtensionsRegistration annotation
    def macro_registration(macro_holder:Class):void;end
end

# registration of macro extensions via java service SPI
# put implementation class name in (META-INF/services/org.mirah.macros.ExtensionsProvider
interface ExtensionsProvider
    def register(service:ExtensionsService):void;end
end