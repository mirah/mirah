# Copyright (c) 2015 The Mirah project authors. All Rights Reserved.
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

package org.mirah.plugin

import mirah.lang.ast.Node
import mirah.lang.ast.NodeScanner
import org.mirah.util.Context

# compiler plugin is an extension point to the mirah compiler
# put implementation class name in (META-INF/services/org.mirah.plugin.CompilerPlugin
interface CompilerPlugin

  # plugin key to identify plugin in mirahc --plugin  pluginKeyA[:PROPERTY_A][,pluginKeyB[:PROPERTY_B]]
  def key:String;end

  # initialize plugin with param string read from mirah arguments --plugin
  def start(param:String, context:Context):void;end

  # called for each AST root node after parse stage finished without errors
  def on_parse(node:Node):void;end

  # called for each AST root node after infer stage finished without errors
  def on_infer(node:Node):void;end

  # called for each AST root node after clean and before compile stage
  def on_clean(node:Node):void;end

  # called once after byte cprocessing
  def stop:void;end
end

# do nothing implementation
class AbstractCompilerPlugin < NodeScanner
  implements CompilerPlugin

  attr_reader context:Context,
              param:String

  def key:String
    @key
  end

# Plugin implementation constructor must be no args calling super('some_key')
  def initialize(key:String):void
    super()
    @context = nil
    @param = nil
    raise "Invalid key: '#{key}'" if key == nil or key.isEmpty or key.contains " "
    @key = key
  end

  def start(param, context):void;
    @param = param
    @context = context
  end

  def on_parse(node:Node)
    return
  end

  def on_infer(node:Node)
    return
  end

  def on_clean(node:Node)
    return
  end

  def stop
    return
  end
end