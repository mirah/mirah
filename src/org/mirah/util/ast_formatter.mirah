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

package org.mirah.util

import java.util.List
import java.util.LinkedList
import mirah.lang.ast.Node
import mirah.lang.ast.NodeScanner

class AstFormatter < NodeScanner
  def initialize(node: Node)
    @out = StringBuilder.new
    @indent = 0
    @newline = true
    @childCounts = LinkedList.new
    @childCounts.addLast(Integer.valueOf(0))
    @node = node
  end
  def appendIndent: void
    @indent.times {@out.append(" ")}
  end
  def appendLine(arg: String): void
    append(arg)
    @newline = true
    @out.append("\n")
  end
  def append(arg: String): void
    appendIndent if @newline
    @out.append(arg)
    @newline = false
  end
  def indent
    @indent += 2
  end
  def dedent
    @indent -= 2
  end
  def enterNullChild(obj)
    appendLine("nil")
  end

  def startNode(node: Node)
    count = Integer(@childCounts.removeLast)
    @childCounts.addLast(Integer.valueOf(count.intValue + 1))
    @childCounts.addLast(Integer.valueOf(0))
    append("[#{node.getClass.getSimpleName}")
    indent
  end

  def enterDefault(node, arg)
    startNode(node)
    appendLine("")
    true
  end

  def exitDefault(node, arg)
    dedent
    childCount = Integer(@childCounts.removeLast).intValue    
    lastIndex = @out.length - 1
    if lastIndex > 0 && @out.charAt(lastIndex) == ?\n &&
       (@out.charAt(lastIndex -1) == ?[ || @out.charAt(lastIndex - 1) == ?])
      @out.insert(lastIndex, "]")
    else
      if childCount == 0
        @out.insert(lastIndex, "]")
      else
        appendLine("]")
      end
    end
    @out
  end
  
  def enterBoolean(node, arg)
    startNode(node)
    append " "
    @out.append(node.value)
    appendLine("")
    true
  end
  def enterFixnum(node, arg)
    startNode(node)
    append " "
    @out.append(node.value)
    appendLine("")
    true
  end
  def enterFloat(node, arg)
    startNode(node)
    append " "
    @out.append(node.value)
    appendLine("")
    true
  end
  def enterCharLiteral(node, arg)
    startNode(node)
    append " "
    @out.append(node.value)
    appendLine("")
    true
  end

  def enterSimpleString(node, arg)
    count = Integer(@childCounts.peekLast).intValue
    if count == 0
      @newline = false
      @out.setCharAt(@out.length - 1, ' '.charAt(0))
    end
    append '"'
    @out.append(node.value)
    true
  end

  def exitSimpleString(node, arg)
    appendLine '"'
  end

  def enterTypeRefImpl(node, arg)
    startNode(node)
    append " #{node.name}"
    append " array" if node.isArray
    append " static" if node.isStatic
    appendLine ""
    true
  end

  def enterNodeList(node, arg)
    count = Integer(@childCounts.removeLast)
    @childCounts.addLast(Integer.valueOf(count.intValue + 1))
    @childCounts.addLast(Integer.valueOf(0))
    appendLine "["
    indent
    true
  end

  def enterBlockArgument(node, arg)
    enterDefault(node, arg)
    appendLine "optional" if node.optional
    true
  end

  def enterLoop(node, arg)
    enterDefault(node, arg)
    appendLine "skipFirstCheck" if node.skipFirstCheck
    appendLine "negative" if node.negative
    true
  end

  def exitFieldAccess(node, arg)
    appendLine "static" if node.isStatic
    exitDefault(node, arg)
  end

  def exitFieldAssign(node, arg)
    appendLine "static" if node.isStatic
    exitDefault(node, arg)
  end  

  def enterUnquote(node, arg)
    enterDefault(node, arg)
    object = node.object
    if object
      if object.kind_of?(Node)
        scan(Node(object), arg)
      elsif object.kind_of?(List) && List(object).all? {|i| i.kind_of?(Node)}
        List(object).each {|o| scan(Node(o), arg)}
      else
        append "<"
        append node.object.toString
        appendLine ">"
      end
    end
    object.nil?
  end
  
  def toString
    @string ||= begin
      scan(@node, nil)
      out = @out
      @out = nil
      @node = nil
      out.toString
    end
  end
end
