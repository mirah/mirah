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

import mirah.lang.ast.*
import org.mirah.typer.Typer

# Ensures the first thing in the constructor is a call to super or another constructor of this class.

class ConstructorCleanup < SimpleNodeVisitor
  def initialize(context:Context)
    @context = context
    @typer = context[Typer]
  end
  
  def clean(constructor:ConstructorDefinition, extra_init:NodeList):void
    found_delegate = constructor.accept(self, extra_init)
    unless Boolean.TRUE.equals(found_delegate)
      delegate = ZSuper.new(constructor.name.position)
      constructor.body.insert(0, delegate)
      @typer.infer(delegate, false)
      insertNodesAfter(delegate, extra_init)
    end
  end
  
  def defaultNode(node, arg)
    nil
  end
  
  # The delegate constructor call must be first, but it could be inside a NodeList or an Ensure/Rescue.
  def visitNodeList(node, arg)
    node.get(0).accept(self, arg) if node.size > 0
  end
  # Note: I'm not sure if java allows these:
  def visitEnsure(node, arg)
    node.body.accept(self, arg) if node.body
  end
  def visitRescue(node, arg)
    node.body.accept(self, arg) if node.body
  end
  
  # A super is perfect.
  def visitZSuper(node, arg)
    insertNodesAfter(node, arg)
    Boolean.TRUE
  end
  def visitSuper(node, arg)
    insertNodesAfter(node, arg)
    Boolean.TRUE
  end
  
  # But we also allow a call to initialize.
  # No need to add the init nodes here in that case, 
  # since the other constructor will contain them.
  def visitFunctionalCall(node, arg)
    if "initialize".equals(node.name.identifier)
      Boolean.TRUE
    else
      nil
    end
  end
  def visitCall(node, arg)
    if node.target.kind_of?(Self) && "initialize".equals(node.name.identifier)
      Boolean.TRUE
    else
      nil
    end
  end
  
  def insertNodesAfter(node:Node, arg:Object):void
    if arg
      parent = NodeList(node.parent)
      parent.insert(1, Node(arg))
      @typer.infer(parent.get(1))
    end
  end
end