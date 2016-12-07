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
import mirah.impl.MirahParser
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.FileInputStream
import java.io.PrintStream

# Minimal Scope implementation for SimpleScoper.
# The main Scopes are is BetterScope in src/org/mirah/jvm/mirrors/better_scope.mirah.
class SimpleScope; implements Scope
  def initialize types: TypeSystem
    @nextTemp = -1
    @imports = HashMap.new
    @search_packages = ArrayList.new
    @types = types
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
    if "*".equals(shortname)
      @search_packages.add(fullname.substring(0, fullname.length - 2))
    else
      @imports[shortname] = fullname
    end
  end

  def getLocalType name, position
    @types.getLocalType( self, name, position).as! LocalFuture
  end

  def imports
    @imports
  end
  def search_packages
    @search_packages
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
  def shadow(name:String):void
    raise UnsupportedOperationException, "Simple scope doesn't know how to shadow."
  end

  def methodUsed name
    # ignored
  end
end
