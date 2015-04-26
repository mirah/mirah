# Copyright (c) 2012-2014 The Mirah project authors. All Rights Reserved.
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

package org.mirah.macros

import java.io.InputStream
import java.util.Arrays
import java.util.Collections
import java.util.HashMap
import java.util.LinkedList
import java.util.List
import mirah.impl.MirahParser
import mirah.lang.ast.Annotation
import mirah.lang.ast.Arguments
import mirah.lang.ast.Array
import mirah.lang.ast.Call
import mirah.lang.ast.Cast
import mirah.lang.ast.ClassDefinition
import mirah.lang.ast.FieldAccess
import mirah.lang.ast.Fixnum
import mirah.lang.ast.HashEntry
import mirah.lang.ast.Import
import mirah.lang.ast.MacroDefinition
import mirah.lang.ast.MethodDefinition
import mirah.lang.ast.Node
import mirah.lang.ast.NodeList
import mirah.lang.ast.NodeScanner
import mirah.lang.ast.Package
import mirah.lang.ast.RequiredArgument
import mirah.lang.ast.Script
import mirah.lang.ast.SimpleString
import mirah.lang.ast.StreamCodeSource
import mirah.lang.ast.StringCodeSource
import mirah.lang.ast.StringConcat
import mirah.lang.ast.TypeName
import mirah.lang.ast.Unquote
import org.mirah.typer.TypeFuture
import org.mirah.typer.Typer

class ValueSetter < NodeScanner
  def initialize(objects: List)
    @index = 0
    @objects = objects
  end

  def enterUnquote(node, arg)
    node.object = @objects.get(@index)
    @index += 1
    true
  end
end

class ValueGetter < NodeScanner
  def initialize
    @values = NodeList.new
  end

  def enterUnquote(node, arg)
    @values.add(node.value)
    true
  end

  def values
    array = Array.new
    array.values = @values
    array
  end
end

# Builds all the macro classes.
#
# It's where the transformation magic happens.
# Whenever there's a macro definition, this slurps it up and converts it into a class.
# It is also responsible for transformations of things like optional arguments and I think,
# managing intrinsics.
#
class MacroBuilder; implements Compiler
  def initialize(typer: Typer, backend: JvmBackend, parser: MirahParser=nil)
    @typer = typer
    @types = typer.type_system
    @scopes = typer.scoper
    @backend = backend
    @extension_counters = HashMap.new
    @parser = parser || MirahParser.new
    @loader = Typer(nil)
  end

  def self.initialize: void
    @@log = java::util::logging::Logger.getLogger(MacroBuilder.class.getName)
  end

  def setMacroLoader(loader: Typer)
    @loader = loader
  end

  def buildExtension(macroDef: MacroDefinition)
    ast = constructAst(macroDef)
    @backend.logExtensionAst(ast)
    @typer.infer(ast)
    klass = @backend.compileAndLoadExtension(ast)
    addToExtensions(macroDef, klass)
    registerLoadedMacro(macroDef, klass)
  end

  def typer
    if @loader
      @loader
    else
      @typer
    end
  end

  def type_system
    if @loader
      @loader.type_system
    else
      @types
    end
  end

  def scoper
    if @loader
      @loader.scoper
    else
      @scopes
    end
  end

  def cast(typename, value)
    t = Unquote.new
    t.object = typename
    v = Unquote.new
    v.object = value
    Cast.new(t, v)
  end

  def serializeAst(node: Node): Object
    raise IllegalArgumentException, "No position for #{node}" unless node.position
    result = Object[5]
    result[0] = SimpleString.new(node.position.source.name)
    result[1] = Fixnum.new(node.position.startLine)
    result[2] = Fixnum.new(node.position.startColumn)
    result[3] = splitString(node.position.source.substring(node.position.startChar,
                                                           node.position.endChar))
    collector = ValueGetter.new
    collector.scan(node)
    result[4] = collector.values
    Arrays.asList(result)
  end

  def deserializeScript(filename: String, code: InputStream, values: List): Script
    script = Script(@parser.parse(StreamCodeSource.new(filename, code)))
    ValueSetter.new(values).scan(script)
    script
  end

  def deserializeAst(filename: String, startLine: int, startCol: int, code: String, values: List): Node
    script = Script(@parser.parse(StringCodeSource.new(filename, code, startLine, startCol)))
    # TODO(ribrdb) scope
    ValueSetter.new(values).scan(script)
    node = if script.body_size == 1
      script.body(0)
    else
      script.body
    end
    node.setParent(nil)
    node
  end

  # If the string is too long split it into multiple string constants.
  def splitString(string: String): Node
    if string.length < 65535
      Node(SimpleString.new(string))
    else
      result = StringConcat.new
      while string.length >= 65535
        result.add(SimpleString.new(string.substring(0, 65535)))
        string = string.substring(65535)
      end
      result.add(SimpleString.new(string))
      result
    end
  end

  def constructAst(macroDef: MacroDefinition): Script
    name = extensionName(macroDef)
    addMissingTypes(macroDef)
    argdef = makeArgAnnotation(macroDef.arguments)
    casts = makeCasts(macroDef.arguments)
    scope = @scopes.getScope(macroDef)
    isStatic = mirah::lang::ast::Boolean.new(macroDef.name.position, macroDef.isStatic || scope.selfType.resolve.isMeta)
    script = Script.new(macroDef.position)
    script.body = quote do
      import org.mirah.macros.anno.*
      import org.mirah.macros.Macro
      import org.mirah.macros.Compiler
      import mirah.lang.ast.CallSite
      import mirah.lang.ast.Node
      import mirah.lang.ast.*

      $MacroDef[name: `macroDef.name`, arguments: `argdef`, isStatic: `isStatic`]
      class `name` implements Macro
        def initialize(mirah: Compiler, call: CallSite)
          @mirah = mirah
          @call = call
        end

        def _expand(`macroDef.arguments.clone`): Node
          `macroDef.body`
        end

        def expand: Node
          _expand(`casts`)
        end

        def gensym: String
          @mirah.scoper.getScope(@call).temp('gensym')
        end
      end
    end
    preamble = NodeList.new

    if scope.package
      preamble.add(Package.new(SimpleString.new(scope.package), nil))
    end
    scope.search_packages.each do |pkg|
      preamble.add(Import.new(SimpleString.new(String(pkg)), SimpleString.new('*')))
    end
    imports = scope.imports
    imports.keySet.each do |key|
      future = @types.get scope, SimpleString.new(String(imports.get(key))).typeref
      if future.isResolved
        preamble.add(Import.new(SimpleString.new(String(imports.get(key))),
                                SimpleString.new(String(key))))
      end
    end
    script.body.insert(0, preamble)
    script
  end

  def extensionName(macroDef: MacroDefinition)
    enclosing_type = @scopes.getScope(macroDef).selfType.resolve
    counter = Integer(@extension_counters.get(enclosing_type))
    if counter.nil?
      id = 1
    else
      id = counter.intValue + 1
    end
    @extension_counters.put(enclosing_type, Integer.new(id))
    "#{enclosing_type.name}$Extension#{id}"
  end

  # Adds types to the arguments with none specified.
  # Uses Block for a block argument and Node for any other argument.
  def addMissingTypes(macroDef: MacroDefinition): void
    macroDef.arguments ||= Arguments.new(Collections.emptyList, Collections.emptyList, nil, Collections.emptyList, nil)
    macroDef.body ||= NodeList.new
    # TODO optional, rest args
    macroDef.arguments.required.each do |arg: RequiredArgument|
      if arg.type.nil?
        arg.type = SimpleString.new('mirah.lang.ast.Node')
      elsif arg.type.typeref.name.indexOf('.') == -1
        arg.type = SimpleString.new("mirah.lang.ast.#{arg.type.typeref.name}")
      end
    end
    block = macroDef.arguments.block
    if block
      type = block.type || SimpleString.new('mirah.lang.ast.Block')
      macroDef.arguments.block = nil
      macroDef.arguments.required.add(
          RequiredArgument.new(block.position, block.name, type))
    end
  end

  def makeCasts(args: Arguments): List
    casts = LinkedList.new
    i = 0
    args.required.each do |arg: RequiredArgument|
      if i == args.required_size() - 1 && arg.type.typeref.name.endsWith("Block")
        casts.add(fetchMacroBlock)
      else
        casts.add(Cast.new(TypeName(arg.type.clone), fetchMacroArg(i)))
      end
      i += 1
    end
    casts
  end

  def makeArgAnnotation(args: Arguments): Annotation
    # TODO other args
    required = LinkedList.new
    args.required_size.times do |i|
      arg = args.required(i)
      name = arg.type.typeref.name
      # FIXME these should probably be inferred instead of assuming the package.
      name = "mirah.lang.ast.#{name}" unless name.startsWith('mirah.lang.ast.')
      required.add(SimpleString.new(arg.position, name))
    end
    entries = [HashEntry.new(SimpleString.new('required'), Array.new(required))]
    Annotation.new(SimpleString.new('org.mirah.macros.anno.MacroArgs'), entries)
  end

  # Returns a node to fetch the i'th macro argument during expansion.
  def fetchMacroArg(i: int): Node
    Call.new(
      Call.new(FieldAccess.new(SimpleString.new('call')),
               SimpleString.new('parameters'), Collections.emptyList, nil),
      SimpleString.new('get'), [Fixnum.new(i)], nil)
  end

  def fetchMacroBlock: Node
    Call.new(FieldAccess.new(SimpleString.new('call')),
             SimpleString.new('block'), Collections.emptyList, nil)
  end

  def addToExtensions(macrodef: MacroDefinition, klass: Class): void
    classdef = ClassDefinition(macrodef.findAncestor(ClassDefinition.class))
    if classdef.nil?
      return
    end
    extensions = Annotation(nil)
    classdef.annotations_size.times do |i|
      anno = classdef.annotations(i)
      if anno.type.typeref.name.equals('org.mirah.macros.anno.Extensions')
        extensions = anno
        break
      end
    end

    if extensions.nil?
      entries = [HashEntry.new(SimpleString.new('macros'), Array.new(Collections.emptyList))]
      extensions = Annotation.new(SimpleString.new('org.mirah.macros.anno.Extensions'), entries)
      classdef.annotations.add(extensions)

      extensions_type = @typer.infer(extensions)
      if @loader
        @loader.learnType(extensions, extensions_type)
      end
    end

    array = Array(extensions.values(0).value)
    new_entry = SimpleString.new(klass.getName)
    entry_type = @typer.infer(new_entry)
    array.values.add(new_entry)
    if @loader
      @loader.learnType(new_entry, entry_type)
    end
  end

  def registerLoadedMacro(macroDef: MacroDefinition, klass: Class): void
    typer = if @loader
      @loader
    else
      @typer
    end
    scopes = if @loader
      @loader.scoper
    else
      @scopes
    end
    
    extended_class = typer.scoper.getScope(macroDef).selfType.resolve
    typer.type_system.addMacro(extended_class, klass)
  end
end
