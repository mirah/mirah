# Copyright (c) 2013 The Mirah project authors. All Rights Reserved.
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

package org.mirah.jvm.mirrors

import java.util.List
import java.util.Map

import mirah.lang.ast.Position
import org.mirah.typer.simple.SimpleScope
import org.mirah.typer.AssignableTypeFuture
import org.mirah.typer.ResolvedType
import org.mirah.typer.Scoper

class JVMScope < SimpleScope
  def initialize(scoper:Scoper=nil)
    @locals = {}
    @scoper = scoper
    @search_packages = []
    @imports = {}
  end

  attr_accessor binding_type:ResolvedType

  def getLocalType(name:String, position:Position)
    type = AssignableTypeFuture(@locals[name])
    if type.nil?
      type = AssignableTypeFuture.new(position)
      @locals[name] = type
    end
    type
  end

  def outer_scope:JVMScope
    node = self.context
    return nil if @scoper.nil? || node.nil? || node.parent.nil?
    JVMScope(@scoper.getScope(node))
  end

  def package
    outer = outer_scope()
    super || (outer && outer.package)
  end

  def fetch_imports(map:Map)
    parent_scope = outer_scope
    parent_scope.fetch_imports(map) if parent_scope

    map.putAll(@imports)
  end

  def fetch_packages(list:List)
    parent_scope = outer_scope
    parent_scope.fetch_packages(list) if parent_scope
    list.addAll(@search_packages)
    list
  end

  def imports
    @cached_imports ||= fetch_imports({})
  end

  def search_packages
    @cached_packages ||= fetch_packages([])
  end

  def import(fullname:String, shortname:String)
    if "*".equals(shortname)
      @search_packages.add(fullname)
    else
      @imports[shortname] = fullname
    end
  end
end