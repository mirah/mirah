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

package org.mirah.jvm.compiler

import mirah.lang.ast.NodeScanner
import org.mirah.typer.ProxyNode

# Replaces ProxyNodes with their selected nodes.
class ProxyCleanup < NodeScanner
  def enterDefault(node, arg)
    true
  end

  def enterNodeList(node, arg)
    if node.kind_of?(ProxyNode)
      child = node.get(0)
      child.setParent(nil)
      node.parent.replaceChild(node, child)
      scan(child, arg)
      false
    else
      true
    end
  end
end
 