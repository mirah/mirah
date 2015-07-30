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

package org.mirah.util

import java.util.ArrayDeque
import java.util.List
import mirah.lang.ast.Node
import mirah.lang.ast.NodeScanner

#
# This class checks the semantic integrity of the abstract syntax tree.
# There is currently only 1 check implemented:
# - Check for whether a node's child has actually the node as parent.
#
class AstChecker < NodeScanner
  
  attr_accessor stack:ArrayDeque

  def self.initialize:void
    @@log = Logger.getLogger(AstChecker.class.getName)
  end
  
  def self.enabled
    false
  end
  
  def initialize
    self.stack = ArrayDeque.new
  end

  def enterDefault(node, arg)
#   @@log.finest("enter #{node}")
    if stack.isEmpty
    else
      parent = Node(stack.getLast)
      if !(node.parent==parent)
        child_parent_mismatch(parent,node,node.parent)
      end
    end
    stack.addLast(node)
    true
  end
  
  def exitDefault(node, arg)
    last = stack.removeLast()
    if !(last==node)
      raise "NodeScanner has a bug."
    end
  end
  
  def child_parent_mismatch(node:Node,nodes_child:Node,nodes_childs_parent:Node)
    @@log.warning "Child #{nodes_child} of #{node} has parent #{nodes_childs_parent}"
  end
  
  def self.maybe_check(node:Node):void
    if self.enabled
      node.accept(self.new, nil)
    end
  end
  
  def self.maybe_check(list:List):void # List<Node>
    if self.enabled
      list.each do |node:Node|
        self.maybe_check(node)
      end
    end
  end
end

