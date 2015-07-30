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

import mirah.lang.ast.*
import org.mirah.typer.Typer
import org.mirah.util.AstFormatter
import org.mirah.util.Context
import java.util.Collections
import java.util.logging.Level
import org.mirah.util.Logger

# Ensures the first thing in the constructor is a call to super or another constructor of this class.

class ConstructorCleanup < SimpleNodeVisitor
  def self.initialize:void
    @@log = Logger.getLogger(ConstructorCleanup.class.getName)
  end
  def initialize(context:Context)
    @context = context
    @typer = context[Typer]
  end
  
  def clean(constructor:ConstructorDefinition, extra_init:NodeList):void
    @@log.log(Level.FINER, "Before cleanup {0}", AstFormatter.new(constructor))
    found_delegate = constructor.body.accept(self, extra_init)
    @@log.finest("found_delegate: #{found_delegate}")
    unless Boolean.TRUE.equals(found_delegate)
      delegate = Super.new(constructor.name.position, Collections.emptyList, nil)
      constructor.body.insert(0, delegate)
      @typer.infer(delegate, false)
      insertNodesAfter(constructor.body.get(0), extra_init)
    end
    @@log.log(Level.FINE, "After cleanup {0}", AstFormatter.new(constructor))
  end
  
  def defaultNode(node, arg)
    nil
  end
  
  # The delegate constructor call must be first, but it could be inside a NodeList or an Ensure/Rescue.
  def visitNodeList(node, arg)
    node.size.times do |i|
      child = node.get(i)
      res = child.accept(self, arg)
      return res if res
    end
  end
  
  # If we find a ClassDefinition in a constructor, then we should ignore it.
  def visitClassDefinition(node, arg)
    nil
  end
  
  # If we find a ClosureDefinition in a constructor (which may happen if the constructor contains closures), then we should ignore it.
  def visitClosureDefinition(node, arg)
    nil
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