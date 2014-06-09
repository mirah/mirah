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

import java.util.ArrayList
import java.util.HashSet
import java.util.List
import java.util.Map
import java.util.Set

import mirah.lang.ast.Position
import org.mirah.typer.simple.SimpleScope
import org.mirah.typer.LocalFuture
import org.mirah.typer.ResolvedType
import org.mirah.typer.Scope
import org.mirah.typer.Scoper
import org.mirah.typer.TypeFuture

class JVMScope < SimpleScope
  def initialize(scoper:Scoper=nil)
    @defined_locals = HashSet.new
    @local_types = {}
    @scoper = scoper
    @search_packages = []
    @imports = {}
    @staticImports = HashSet.new
    @children = HashSet.new
    @shadowed = HashSet.new
  end

  def binding_type:ResolvedType
    if parent
      parent.binding_type
    else
      @binding_type
    end
  end

  def binding_type=(type:ResolvedType):void
    if parent
      parent.binding_type = type
    else
      @binding_type = type
    end
  end

  def getLocalType(name:String, position:Position)
    type = LocalFuture(@local_types[name])
    if type.nil?
      type = LocalFuture.new(name, position)
      locals = @defined_locals
      type.onUpdate do |x, resolved|
        if resolved.isError
          locals.remove(name)
        else
          locals.add(name)
        end
      end
      if @parent && !shadowed?(name)
        type.parent = @parent.getLocalType(name, position)
      end
      @local_types[name] = type
    end
    type
  end

  def hasLocal(name:String, includeParent:boolean=true)
    @defined_locals.contains(name) ||
        (includeParent && @parent && @parent.hasLocal(name))
  end

  def shadowed? name: String
    @shadowed.contains(name)
  end

  def isCaptured(name)
    if !@defined_locals.contains(name)
      return false
    elsif @parent && @parent.hasLocal(name)
      return true
    else
      return @children.any? {|child| JVMScope(child).hasLocal(name, false)}
    end
  end

  def capturedLocals
    captured = ArrayList.new(@defined_locals.size)
    @defined_locals.each {|name| captured.add(name) if isCaptured(String(name))}
    captured
  end

  def addChild(scope:JVMScope)
    @children.add(scope)
  end

  def removeChild(scope:JVMScope)
    @children.remove(scope)
  end

  def parent; @parent; end

  def parent=(parent:Scope):void
    @parent.removeChild(self) if @parent
    JVMScope(parent).addChild(self)
    @parent = JVMScope(parent)
    flush
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

  def fetch_static_imports(set:Set)
    parent_scope = outer_scope
    parent_scope.fetch_static_imports(set) if parent_scope
    set.addAll(@staticImports)
    set
  end

  def imports
    @cached_imports ||= fetch_imports({})
  end

  def search_packages
    @cached_packages ||= fetch_packages([])
  end

  def import(fullname:String, shortname:String)
    flush
    if "*".equals(shortname)
      @search_packages.add(fullname)
    else
      @imports[shortname] = fullname
    end
  end

  def selfType:TypeFuture
    if @selfType.nil? && parent
      @selfType = parent.selfType
    end
    @selfType
  end
  def selfType=(type:TypeFuture):void
    @selfType = type
  end

  def staticImport(type)
    flush
    @staticImports.add(type)
  end
  
  def staticImports:Set
    @cached_static_imports ||= fetch_static_imports(HashSet.new)
  end

  def flush
    @cached_imports = Map(nil)
    @cached_packages = List(nil)
    @cached_static_imports = Set(nil)
  end

  def shadow(name:String):void
    @defined_locals.add name
    @shadowed.add name
  end
end