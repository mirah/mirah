# Copyright (c) 2013-2014 The Mirah project authors. All Rights Reserved.
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
import mirah.lang.ast.Node
import mirah.lang.ast.ClassDefinition
import mirah.lang.ast.MethodDefinition
import mirah.lang.ast.ClassAppendSelf
import mirah.lang.ast.Block
import mirah.lang.ast.RescueClause
import mirah.lang.ast.Script
import mirah.lang.ast.Package

import org.mirah.typer.LocalFuture
import org.mirah.typer.ErrorMessage
import org.mirah.typer.ErrorType
import org.mirah.typer.ResolvedType
import org.mirah.typer.Scope
import org.mirah.typer.Scoper
import org.mirah.typer.simple.ScopeFactory
import org.mirah.typer.TypeFuture


# The idea behind "better" scope is to break out all the 
# different types of scope, to make it easier to define how
# different scopes work.
#
# The current impl has one type of scope for everything, which
# ends up making certain kinds of things tricky because you can't
# have different behavior for different scopes.
#
# things that can be closed over
# - locals
# - self, explicit and implicit
# - fields
# - methods
#

# contains locals for scope
class Locals
  implements Iterable
  def initialize
    @defined_locals = HashSet.new
    @local_types    = {}
  end

  def local_type(
    name: String,
    position: Position,
    parent: BetterScope,
    shadowed: boolean
  )
    type = @local_types[name].as!(LocalFuture)
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

      if parent && !shadowed
        type.parent = parent.as!(BetterScope).getLocalType(name, position)
      end
      @local_types[name] = type
    end
    type
  end
  
  def has_local name: String
    @defined_locals.contains(name)
  end

  def size; @defined_locals.size; end
  def iterator; @defined_locals.iterator; end
end

# holds onto constant lookup structures
class ImportsAndSearchPackages
  attr_reader imports: Map, search_packages: List, staticImports: Set
  def initialize
    @search_packages = []
    @imports         = {}
    @staticImports   = HashSet.new
  end

  def add(fullname: String, shortname: String): void
    if "*".equals(shortname)
      @search_packages.add(fullname)
    else
      @imports[shortname] = fullname
    end
  end

  def addStaticImport(type: TypeFuture): void
    @staticImports.add type
  end

  def collect_imports(map: Map, outer_scope: MirrorScope): Map
    outer_scope.fetch_imports map if outer_scope
    map.putAll @imports
    map
  end

  def collect_search_packages(list: List, outer_scope: MirrorScope): List
    outer_scope.fetch_packages list if outer_scope
    list.addAll @search_packages
    list
  end

  def collect_static_imports(set: Set, outer_scope: MirrorScope): Set
    outer_scope.fetch_static_imports set if outer_scope
    set.addAll(@staticImports)
    set
  end
end

class BetterScopeFactory
  implements ScopeFactory
  def newScope(scoper: Scoper, node: Node): Scope
    if node.kind_of? ClassDefinition
      ClassScope.new scoper, node
    elsif node.kind_of?(Script) || node.kind_of?(Package)
      ScriptScope.new scoper, node
    elsif node.kind_of?(MethodDefinition) || node.kind_of?(ClassAppendSelf)
      MethodScope.new scoper, node
    elsif node.kind_of? Block
      ClosureScope.new scoper, node
    elsif node.kind_of? RescueClause
      RescueScope.new scoper, node
    else
      raise "unhandled node type #{node}"
    end
  end
end

# has all the tree bits, macros for making scopes declarative
class BetterScope
  implements Scope, MirrorScope

  def initialize(context: Node)
    @parent = BetterScope(nil)
    @children = []
    @tmpCounter = 0

    @context = context
  end

  def addChild(scope: BetterScope)
    @children.add(scope)
  end

  def removeChild(scope: BetterScope)
    @children.remove(scope)
  end

  # override
  def parent; @parent; end
  # override
  def parent=(new_parent: Scope):void
    # Don't add self as my parent, this means that
    # we're in a closure in the process of being replaced
    import static org.mirah.util.Comparisons.*
    return if areSame(self, new_parent)

    @parent.removeChild(self) if @parent

    new_parent.as!(BetterScope).addChild(self)
    @parent = new_parent.as!(BetterScope)

    flush
  end

  def flush
    flush_selfType
    flush_imports
    @children.each{|c: BetterScope| c.flush }
  end

  # override
  def selfType:TypeFuture; raise "no self type for #{getClass}" end  # Should this be resolved?
  def selfType=(type:TypeFuture):void; raise "no self type for #{getClass}, so cant assign" end


  def selfUsed(): void; raise "selfUsed: no self capturing for #{getClass}" end
  def capturedSelf: boolean; raise "capturedSelf: no self capturing for #{getClass}" end
  def hasSelf: boolean; raise "hasSelf: no self capturing for #{getClass}" end

  # override
  def context:Node; @context end
  
  # override
  def shadow(name:String):void; raise "no shadowing for #{getClass}" end
  def shadowed?(name:String):boolean; raise "no shadowing for #{getClass}" end
  
  # override
  def hasLocal(name:String, includeParent:boolean=true):boolean; raise "no locals for #{getClass}" end

  # override
  def isCaptured(name:String):boolean; raise "isCaptured: no captures for #{getClass}" end
  # List of captured local variable names
  def capturedLocals:List;
    []
  end

  # override
  def import(fullname:String, shortname:String):void; raise "import: no imports for #{getClass}" end
  def staticImport(type:TypeFuture):void; raise "staticImport no imports for #{getClass}" end
  def imports:Map;  raise "imports: no imports for #{getClass}" end  # Map of short -> long; probably should be reversed.

  # override
  def package:String; raise "no package for #{getClass}" end
  def package=(package:String):void; raise "no package= for #{getClass}" end

  # override
  def search_packages:List; raise "no search_packages package for #{getClass}" end

  # override  
  def temp(name:String):String; "#{name}#{@tmpCounter+=1}" end

  # override
  def binding_type:ResolvedType; raise "no binding_type for #{getClass}"  end
  def binding_type=(type: ResolvedType):void; raise "no binding_type= for #{getClass}" end

  # override
  def declared_binding_type: ResolvedType; raise "no declared_binding_type for #{getClass}"  end
  def declared_binding_type=(type):void; raise "no declared_binding_type= for #{getClass}"  end

  # override
  def hasField(name: String, includeParent:boolean=true): boolean; raise "no fields for #{getClass}.hasField" end
  def fieldUsed(name: String): void; raise "no fields for #{getClass}.fieldUsed" end
  def capturedFields(): List; raise "no fields for #{getClass}.capturedFields" end
  def isCapturedField(name: String): boolean; raise "no fields for #{getClass}.isCapturedField" end

  # override
  def hasMethodCall(name: String, includeParent:boolean=true): boolean; raise "no hasMethodCall for #{getClass}" end
  def methodUsed(name: String): void; raise "no methodUsed for #{getClass}" end
  def capturedMethods(): List; raise "no capturedMethods for #{getClass}" end
  def isCapturedMethod(name: String): boolean; raise "no isCapturedMethod for #{getClass}" end

  def find_class_parent
    cur_parent = parent
    while cur_parent && !cur_parent.kind_of?(ClassScope)
      cur_parent = cur_parent.parent
    end
    cur_parent
  end

  def anyChildOrChildsChildHasField(name: String): boolean
    children.any? do |child: BetterScope|
      if child.hasField(name, false)
        true
      else
        child.anyChildOrChildsChildHasField name
      end
    end
  end

  def anyChildOrChildsChildHasMethodCall(name: String): boolean
    children.any? do |child: BetterScope|
      if child.hasMethodCall(name, false)
        true
      else
        child.anyChildOrChildsChildHasMethodCall name
      end
    end
  end

  def anyChildOrChildsChildHasSelf: boolean
    children.any? do |child: BetterScope|
      if child.kind_of? ClosureScope
        child.hasSelf
      else
        child.anyChildOrChildsChildHasSelf
      end
    end
  end

  #mirrorscope overrides
  def getLocalType(name, position); raise "no locals for #{getClass}.getLocalType" end

  def outer_scope: MirrorScope; raise "no outer_scope for #{getClass}" end 
  
  def staticImports:                        Set; raise "no staticImports for #{getClass}" end
  def fetch_imports(something: Map):        Map; raise "no fetch_imports imports for #{getClass}"  end
  def fetch_static_imports(something: Set): Set; raise "no fetch_static_imports for #{getClass}"  end

  def fetch_packages(list: List): List; raise "no fetch_packages for #{getClass}"  end

  def flush_selfType: void; end
  def flush_imports: void; end
  def children; @children; end

  macro def self.defers_temp
    quote do
      def temp(name)
        if parent # Lazy defer... if it is not possible, we fall back to ourselves.
                  # Hope that does not hurt us (e.g. in case the parent is dynamically added).
          parent.temp(name)
        else
          super
        end
      end
    end
  end

  # no self type assign, defers selfType to parent
  macro def self.defers_selfType
    quote do
      def selfType: TypeFuture 
        # defer to parents, but cache
        @cachedSelfType ||= parent.selfType if parent
      end
      def flush_selfType; @cachedSelfType = nil end
    end
  end

  macro def self.has_own_selfType
    quote do
      def selfType
        @selfType
      end
      def selfType= type
        @selfType = type
      end
    end
  end

  macro def self.defers_binding_type
    quote do
      def declared_binding_type=(type): void
        if parent
          parent.declared_binding_type = type
        end
      end
      def declared_binding_type: ResolvedType
        if parent
          parent.declared_binding_type
        end
      end
      def binding_type: ResolvedType
        if parent
          parent.binding_type
        end
      end
    end
  end

  macro def self.does_binding_type_thing
    quote do
      def declared_binding_type=(type: ResolvedType): void
        @declared_binding_type = type
      end
      def declared_binding_type
        @declared_binding_type
      end
      def binding_type: ResolvedType
        if parent
          parent.binding_type
        else
          @binding_type
        end
      end

      def binding_type=(type: ResolvedType): void
        if parent
          parent.binding_type = type
        else
          @binding_type = type
        end
      end
    end
  end

  # requires #@locals: Locals
  macro def self.supports_locals
    quote do
      def getLocalType(name, position)
        @locals.local_type name, position, parent.as!(BetterScope), shadowed?(name)
      end

      def hasLocal(name, includeParent:boolean=true)
        @locals.has_local(name) || (includeParent && parent && parent.hasLocal(name))
      end
    end
  end

  macro def self.has_no_locals
    quote do
      def getLocalType(name, position)
        future = LocalFuture.new name, position
        # TODO This error message could be better.
        future.resolved ErrorType.new([
          ErrorMessage.new("can't use local '#{name}'. (#{getClass} doesn't support locals)",
                           position)])
        future
      end

      def hasLocal(name, includeParent:boolean=true)
        false
      end
    end
  end

  macro def self.defers_locals
    quote do
      def getLocalType(name, position)
        parent.as!(MirrorScope).getLocalType(name, position)
      end

      def hasLocal(name, includeParent:boolean=true)
        (includeParent && parent && parent.hasLocal(name))
      end
    end
  end

  macro def self.defers_fields
    quote do
      def hasField(name, includeParent:boolean=true)
        (includeParent && parent && parent.hasField(name))
      end

      def capturedFields
        # find the parent scope that is a class scope,
        # then use its captured fields
        cur_parent = find_class_parent
        if cur_parent
          cur_parent.capturedFields
        else
          []
        end
      end

      def fieldUsed name
        parent.fieldUsed name if parent
      end


      def hasMethodCall(name, includeParent:boolean=true)
        (includeParent && parent && parent.hasMethodCall(name))
      end

      def capturedMethods
        # find the parent scope that is a class scope,
        # then use its captured fields
        cur_parent = find_class_parent
        if cur_parent
          cur_parent.capturedMethods
        else
          []
        end
      end

      def methodUsed name
        parent.methodUsed name if parent
      end


      def selfUsed(): void
        parent.selfUsed if parent
      end

      def capturedSelf: boolean
        cur_parent = find_class_parent
        if cur_parent
          cur_parent.capturedSelf
        else
          false
        end
      end

      def hasSelf:boolean
        false
      end

    end
  end

  # must support locals
  macro def self.can_have_locals_captured
    quote do
      def isCaptured(name)
        return false unless @locals.has_local(name)
        return true if parent && parent.hasLocal(name)

        return children.any? do |child: BetterScope|
          if child.hasLocal(name, false)
            true
          else
            false
          end
        end
      end

      def capturedLocals
        captured = ArrayList.new(@locals.size)
        @locals.each {|name: String| captured.add(name) if isCaptured(name)}
        captured
      end
    end
  end

  macro def self.can_have_fields_captured
    quote do
      def isCapturedField(name)
        return false unless @fields_used.contains(name)

        return anyChildOrChildsChildHasField name
      end

      def capturedFields
        captured = ArrayList.new(@fields_used.size)
        @fields_used.each {|name: String| captured.add(name) if isCapturedField(name)}
        captured
      end

      def isCapturedMethod(name)
        #return false unless @methods_used.contains(name)
        # we check the self type before use.
        # Also, you can't know for sure when a method is declared because it may be from a super class.
        return anyChildOrChildsChildHasMethodCall name
      end

      def capturedMethods
        captured = ArrayList.new(@methods_used.size)
        @methods_used.each {|name: String| captured.add(name) if isCapturedMethod(name)}
        captured
      end


      def capturedSelf
        anyChildOrChildsChildHasSelf
      end
    end
  end

  macro def self.defers_captures
    quote do
      def isCaptured(name)
        parent && parent.isCaptured(name)
      end

      def capturedLocals
        if parent
          parent.capturedLocals
        else
          []
        end
      end
    end
  end

  # no shadowing allowed
  macro def self.no_shadowing
    quote do
      def shadowed?(name) false; end
    end
  end

  macro def self.has_outer_scope
    quote do
      def outer_scope
        return nil if @scoper.nil? || context.nil? || context.parent.nil?
        MirrorScope(@scoper.getScope(context))
      end
    end
  end

  # reqs @imports
  # this means the scope both can have imports, and also looks them up in outer scopes
  macro def self.has_own_imports_and_looks_up
    quote do
      has_outer_scope
      def flush_imports: void
        @cached_imports = nil
        @cached_package = nil
        @cached_search_packages = nil
        @cached_static_imports = nil
      end
      
      def fetch_imports(map: Map)
        @imports.collect_imports map, outer_scope
      end

      def fetch_packages(list: List)
        @imports.collect_search_packages list, outer_scope
      end

      def fetch_static_imports(set: Set)
        @imports.collect_static_imports set, outer_scope
      end

      def imports
        @cached_imports ||= fetch_imports({})
      end

      def search_packages
        @cached_search_packages ||= fetch_packages []
      end

      def staticImports: Set
        @cached_static_imports ||= fetch_static_imports(HashSet.new)
      end

      def add_import(fullname: String, shortname: String)
        self.import(fullname, shortname)
      end
      
      def import(fullname: String, shortname: String)
        flush
        @imports.add fullname, shortname
      end

      def staticImport(type)
        flush
        @imports.addStaticImport(type)
      end
    end
  end

  macro def self.deferred_package
    quote do
      #defer to parent^H^H^H^H^H outer_scope
      def package
        @cached_package ||= outer_scope && outer_scope.package#parent.package if parent
      end
    end
  end

  #requires @scoper
  # things that do this have no packages / imports of their own
  # they look them up
  macro def self.deferred_packages_and_imports
    quote do
      deferred_package
      has_outer_scope

      def flush_imports: void
        @cached_imports = nil
        @cached_package = nil
        @cached_search_packages = nil
        @cached_static_imports = nil
      end

      #todo flush? / allow imports in method? required?
      def fetch_imports(map)
        parent_scope = outer_scope
        parent_scope.fetch_imports(map) if parent_scope

        #map.putAll(@imports)
        map
      end
      def imports
        @cached_imports ||= fetch_imports({})
      end

      def fetch_packages(list)
        parent_scope = outer_scope
        parent_scope.fetch_packages(list) if parent_scope
        list
      end

      #defer to parent
      def search_packages
        @cached_search_packages ||= fetch_packages []
      end

      def staticImports: Set
        @cached_static_imports ||= fetch_static_imports(HashSet.new)
      end

      def fetch_static_imports(set)
        parent_scope = outer_scope
        parent_scope.fetch_static_imports(set) if parent_scope
        
        set
      end
    end
  end
end

#
# ClassScope is the scope used for a class declaration.
# Class bodies in Mirah can't have local variables.
# It can't shadow names.
class ClassScope < BetterScope
  def initialize(scoper: Scoper, context: Node)
    super context
    @scoper = scoper

    @imports = ImportsAndSearchPackages.new
    @fields_used = HashSet.new
    @methods_used = HashSet.new
  end

  defers_temp
  has_own_imports_and_looks_up
  deferred_package
  has_own_selfType
  no_shadowing
  has_no_locals
  does_binding_type_thing
  can_have_fields_captured

  def hasField(name, includeParent)
    @fields_used.contains(name) || (includeParent && parent.hasField(name))
  end

  def fieldUsed(name)
    @fields_used.add name
  end


  def hasMethodCall(name, includeParent)
    @methods_used.contains(name) || (includeParent && parent.hasMethodCall(name))
  end

  def methodUsed(name)
    @methods_used.add name
  end


  def hasSelf
    # ignore
  end

end

class ClosureScope < BetterScope

  def toString
    "<ClosureScope local_captures=#{capturedLocals} field_usages=#{@fields_used} methods_used=#{@methods_used}>"
  end

  defers_temp
  has_own_imports_and_looks_up
  supports_locals
  deferred_package

  can_have_locals_captured
  
  # weird that I didn't seem to need this. Trying it
  defers_binding_type

  # for the moment, no shadowing,
  # but once scopes support declarations, then yes
  no_shadowing

  attr_accessor closureType: TypeFuture


  # shadows parameters, everything else captured
  def initialize(scoper: Scoper, context: Node)
    super context
    @scoper = scoper
    @locals = Locals.new
    @imports = ImportsAndSearchPackages.new

    @fields_used = HashSet.new
    @methods_used = HashSet.new
  end

  def fieldUsed name
    selfUsed
    @fields_used.add name
  end

  def hasField(name, includeParent)
    @fields_used.contains(name) || (includeParent && parent.hasField(name))
  end


  def methodUsed name
    selfUsed
    @methods_used.add name
  end

  def hasMethodCall(name, includeParent)
    @methods_used.contains(name) || (includeParent && parent.hasMethodCall(name))
  end


  def selfUsed(): void
    @capturedSelf = true
  end

  def hasSelf
    @capturedSelf
  end

  def selfType: TypeFuture
    parent.selfType
  end

  def internal_locals
    @locals
  end
  
  def internal_imports
    @imports
  end
  
  def internal_scoper
    @scoper
  end
end

class RescueScope < BetterScope
  # shadows parameters, everything else captured
  def initialize(scoper: Scoper, context: Node)
    super context
    @scoper = scoper
    @locals = Locals.new
    @shadowed = HashSet.new
    @imports = ImportsAndSearchPackages.new
  end

  defers_temp
  deferred_package
  has_own_imports_and_looks_up
  defers_selfType
  defers_binding_type
  # for now, until declarations. rescues should defer locals, apart from args
  # eg
  # begin
  #   raise "wut"
  # rescue => e
  #   x = 1
  # end
  # puts x

  supports_locals
  defers_captures
  defers_fields

  def shadow(name)
    @shadowed.add name
  end

  def shadowed? name
    @shadowed.contains(name)
  end
  #defers_locals
  # no for now, until declarations
  #no_shadowing

end


class MethodScope < BetterScope
  def initialize(scoper: Scoper, context: Node)
    super context
    @scoper  = scoper
    @locals  = Locals.new
    @imports = ImportsAndSearchPackages.new
  end
  
  def initialize(source: ClosureScope, context: Node)
    super context
    @scoper     = source.internal_scoper
    @locals     = source.internal_locals
    @imports    = source.internal_imports
    self.parent = source.parent
  end

  def toString
    "<MethodScope type=#{selfType}>"
  end

  defers_temp

  supports_locals
  can_have_locals_captured

  has_own_selfType # is the method type
  deferred_package
  has_own_imports_and_looks_up
  does_binding_type_thing

  defers_fields

  # methods can't shadow locals, because scopes outside them can't share locals w/ them.
  no_shadowing

end

class ScriptScope < BetterScope
  def initialize(scoper: Scoper, context: Node)
    super context
    @scoper = scoper
    
    @imports = ImportsAndSearchPackages.new
    @locals = Locals.new
    @fields_used = HashSet.new
    @methods_used = HashSet.new
  end

  supports_locals
  can_have_locals_captured
  has_own_selfType
  # scripts can't shadow locals, because there are no scopes outside them.
  no_shadowing
  does_binding_type_thing
  has_own_imports_and_looks_up


  can_have_fields_captured

  # scripts can have packages
  def package
    @package
  end

  def package=(p: String): void
    @package = p
  end


  def fieldUsed name
    @fields_used.add name
  end

  def methodUsed name
    @methods_used.add name
  end

  def hasSelf
    # ignore
  end
  # scripts have no outer scope, they are the outer most, but has_own_imports_and_looks_up adds one
#  def outer_scope
#    nil
#  end
end