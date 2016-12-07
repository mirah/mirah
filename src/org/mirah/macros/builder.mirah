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
import mirah.lang.ast.OptionalArgument
import mirah.lang.ast.RequiredArgumentList
import mirah.lang.ast.LocalAssignment
import mirah.lang.ast.Script
import mirah.lang.ast.SimpleString
import mirah.lang.ast.StringCodeSource
import mirah.lang.ast.StringConcat
import mirah.lang.ast.TypeName
import mirah.lang.ast.TypeRefImpl
import mirah.lang.ast.Unquote
import mirah.lang.ast.FunctionalCall
import mirah.lang.ast.TypeRefImpl
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
class MacroBuilder; implements org.mirah.macros.Compiler
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
    arguments = macroDef.arguments
    if arguments and  arguments.optional.size > 0

      optional = arguments.optional

      (optional.size + 1).times do |i:int|

        required_list = []
        local_list = []

        arguments.required.each do |arg: RequiredArgument|
          required_list.add arg
        end

        optional.size.times do |j:int|
          arg = optional.get(j)
          if j < i
            required_list.add RequiredArgument.new(arg.position, arg.name, arg.type)
          else
            local_list.add arg
          end
        end


        cloned  = MacroDefinition(macroDef.clone)
        cloned.arguments = Arguments.new(macroDef.position, required_list, Collections.emptyList, nil, Collections.emptyList, nil)

        local_list.each do |opt_arg:OptionalArgument|
          cloned.body.insert(0, LocalAssignment.new(cloned.body.position,
                                  opt_arg.name,
                                  Cast.new(cloned.body.position,
                                      opt_arg.type,
                                      opt_arg.value)
                                )
                             )
        end
        @@log.fine "build extension required: #{required_list} local: #{local_list}"
        buildExtension(cloned, macroDef)
      end

    else
      buildExtension(macroDef, macroDef)
    end

  end

  def buildExtension(cloned: MacroDefinition, orig: MacroDefinition)
    @scopes.copyScopeFrom(orig, cloned)
    ast = constructAst(cloned)
    @backend.logExtensionAst(ast)
    @typer.infer(ast)
    klass = @backend.compileAndLoadExtension(ast)

    class_def = ClassDefinition(orig.findAncestor(ClassDefinition.class))

    addToExtensions(class_def, klass)
    registerLoadedMacro(cloned, klass)
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
      import java.lang.reflect.Array as ReflectArray

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

        def _varargs(index:int, type:Class ):Object
          parameters = @call.parameters
          block = @call.block
          vsize = parameters.size - index

          vargs = if block
            ReflectArray.newInstance(type, vsize + 1)
          else
            ReflectArray.newInstance(type, vsize)
          end

          # add block as last item
          ReflectArray.set(vargs, vsize, type.cast(block)) if block

          # downcount
          while vsize > 0
            vsize -= 1
            ReflectArray.set(vargs, vsize, type.cast(parameters.get(index + vsize)))
          end
          vargs
        end

        def gensym: String
          @mirah.scoper.getScope(@call).temp('$gensym')
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

  # Macro names are defined as <declaring-type>$Extensions$<macro-name><opt-counter>
  #
  def extensionName(macroDef: MacroDefinition)
    macro_mangled = macroDef.name.identifier.
                      replace('[','lbracket_').
                      replace(']','rbracket_').
                      replace('+', 'plus_').
                      replace('-', 'minus_').
                      replace('=', 'eq_').
                      replace('>', 'gt_').
                      replace('<', 'lt_').
                      replace('/', 'div_').
                      replace('?', 'q_').
                      replace('!', 'not_').
                      replace('&', 'amp_').
                      replace('^', 'xor_').
                      replace('|', 'pipe_').
                      replace('*', 'mult_').
                      replace('@', 'at_').
                      replace('%', 'percent_').
                      replace('~', 'tilde_')
    base_name = "#{registerableTypeName(macroDef)}$#{macro_mangled}"
    ct = counter_for_name(base_name)
    if ct > 0
      "#{base_name}#{ct}"
    else
      base_name
    end
  end


  def counter_for_name(macro_def_name_klass: String)
    # TODO, I think the .intValue / cast in put may be unnecessary
    counter = Integer(@extension_counters.get(macro_def_name_klass))
    if counter.nil?
      id = 0
    else
      id = counter.intValue + 1
    end
    @extension_counters.put(macro_def_name_klass, Integer.new(id))
    id
  end

  def registerableTypeName(macroDef: MacroDefinition)
    enclosing_type = @scopes.getScope(macroDef).selfType.peekInferredType
    if !enclosing_type.isError
      "#{enclosing_type.name}$Extensions"
    else
      raise InternalError.new("Cannot use error type #{enclosing_type} as base name for macros.")
    end
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

    macroDef.arguments.optional.each do |oarg: RequiredArgument|
      if oarg.type.nil?
        oarg.type = SimpleString.new('mirah.lang.ast.Node')
      elsif oarg.type.typeref.name.indexOf('.') == -1
        oarg.type = SimpleString.new("mirah.lang.ast.#{oarg.type.typeref.name}")
      end
    end

    rarg = macroDef.arguments.rest
    if rarg
      if rarg.type.nil?
        rarg.type = SimpleString.new('mirah.lang.ast.Node')
      elsif rarg.type.typeref.name.indexOf('.') == -1
        rarg.type = SimpleString.new("mirah.lang.ast.#{rarg.type.typeref.name}")
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
        macro_arg_node = fetchMacroArg(i)
        # Hack to allow chained macro invocations on macro invocations on MethodDefinitions.
        # To remove this hack, https://github.com/mirah/mirah/issues/423 needs to be fixed.
        macro_arg_node = wrap_dereference(macro_arg_node) if arg.type.typeref.name.endsWith("MethodDefinition")   
        casts.add(Cast.new(TypeName(arg.type.clone), macro_arg_node))
      end
      i += 1
    end
    if args.rest
      rtype_name = args.rest.type.typeref.name
      array_type = TypeRefImpl.new(rtype_name, true)
      type = TypeRefImpl.new(rtype_name, false)
      casts.add(
        Cast.new(array_type, fetchMacroVarArg(i, type))
      )
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
    if args.rest
      name = args.rest.type.typeref.name
      # FIXME these should probably be inferred instead of assuming the package.
      name = "mirah.lang.ast.#{name}" unless name.startsWith('mirah.lang.ast.')
      entries.add HashEntry.new(SimpleString.new('rest'), SimpleString.new(name))
    end
    Annotation.new(SimpleString.new('org.mirah.macros.anno.MacroArgs'), entries)
  end

  # Returns a node to fetch the i'th macro argument during expansion.
  def fetchMacroArg(i: int): Node
    Call.new(
      Call.new(FieldAccess.new(SimpleString.new('call')),
               SimpleString.new('parameters'), Collections.emptyList, nil),
      SimpleString.new('get'), [Fixnum.new(i)], nil)
  end

  # Returns a node to fetch the i'th macro argument during expansion.
  def fetchMacroVarArg(i: int, type: TypeName): Node
    index = Fixnum.new(i)
    clazz = Call.new(type, SimpleString.new('class'), Collections.emptyList, nil)
    FunctionalCall.new(SimpleString.new('_varargs'), [Fixnum.new(i), clazz], nil)
  end

  def wrap_dereference(node: Node): Node
    Call.new(
      TypeRefImpl.new('org.mirah.typer.ProxyNode', false, false, nil),
      SimpleString.new('dereference'),
      [
        node,
      ],
      nil
    )
  end

  def fetchMacroBlock: Node
    Call.new(FieldAccess.new(SimpleString.new('call')),
             SimpleString.new('block'), Collections.emptyList, nil)
  end

  def addToExtensions(classdef: ClassDefinition, klass: Class): void
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
    
    extended_class = typer.scoper.getScope(macroDef).selfType.peekInferredType
    typer.type_system.addMacro(extended_class, klass)
  end
end
