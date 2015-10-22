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

package org.mirah.plugin.impl

import mirah.lang.ast.*
import org.mirah.plugin.*
import org.mirah.typer.*
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.JVMTypeUtils
import mirah.impl.MirahParser
import org.mirah.tool.MirahArguments
import org.mirah.util.Logger
import java.util.*
import java.io.*

# generates java stub file for javadoc or other processing
# preserve java doc style comments
# mirahc -plugin stub[:optional_dir] ...
# mirahc -plugin stub:* ... redirects output to System.out
# TODO add tests
class JavaStubPlugin < AbstractCompilerPlugin

  def self.initialize
    @@log = Logger.getLogger JavaStubPlugin.class.getName
  end

  def initialize:void
    super('stub')
  end

  def start(param, context)
    super(param, context)
    context[MirahParser].skip_java_doc false
    args = context[MirahArguments]
    @typer = context[Typer]
    @@log.fine "typer: #{@typer} args: #{args}"
    @stub_dir = (param != nil and param.trim.length > 0) ? param.trim : args.destination
    @@log.fine "stub dir: '#{@stub_dir}' mirahc destination: '#{args.destination}'"
    @encoding = args.encoding
    @defs = Stack.new
    @writers = []
  end

  def typer:Typer
    @typer
  end

  def encoding:String
    @encoding
  end

  def stub_dir:String
    @stub_dir
  end

  def on_clean(node)
    node.accept self, nil
  end

  def exitScript(node, ctx)
    iter = @writers.iterator
    while iter.hasNext
       ClassStubWriter(iter.next).generate
    end
    clear
    node
  end

  def clear
    @package = nil
    @defs.clear
    @writers.clear
  end

  def current:ClassStubWriter
    ClassStubWriter(@defs.peek)
  end

  def enterPackage(node, ctx)
    @package = node.name.identifier
    false
  end

  def enterMethodDefinition(node, ctx)
    current.add_method node
    false
  end

  def enterStaticMethodDefinition(node, ctx)
    current.add_method node
    false
  end

  def enterConstructorDefinition(node, ctx)
    current.add_method node
    false
  end

  def enterClassDefinition(node, ctx)
    new_writer node
    true
  end

  def exitClassDefinition(node, ctx)
    @defs.pop
    nil
  end

  def enterInterfaceDeclaration(node, ctx)
    new_writer node
    true
  end

  def exitInterfaceDeclaration(node, ctx)
    @defs.pop
    nil
  end

  def enterNodeList(node, ctx)
    # Scan the children
    true
  end

  def enterClassAppendSelf(node, ctx)
    # Scan the children
    true
  end

  def enterFieldDeclaration(node, ctx)
    current.add_field node
    false
  end

  def enterMacroDefinition(node, ctx)
    @@log.fine "enterMacroDefinition #{node}"
    false
  end

  def new_writer(node:ClassDefinition):void
     stub_writer = ClassStubWriter.new self, node
     stub_writer.set_package @package
     @writers.add stub_writer
     @defs.add stub_writer
  end

end

interface ModifierVisitor
  # ACCESS = 0 # compiler error if used
  # FLAG = 1 # compiler error if used
  def visit(type:int, value:String):void;end
end

interface AnnotationVisitor
  def visit(anno:Annotation, anno_type:JVMType, key:String, value:Node):void;end
end

class StubWriter

  def self.initialize
    @@log = Logger.getLogger StubWriter.class.getName
  end

  def typer:Typer
    @typer
  end

  def initialize(typer:Typer)
    @typer = typer
  end

  def generate:void
  end

  def writer_set(w:Writer)
    @writer = w
  end

  def writer:Writer
    @writer
  end

  def writeln(part1:Object=nil, part2:Object=nil, part3:Object=nil, part4:Object=nil, part5:Object=nil):void
     write part1, part2, part3, part4, part5
     @writer.write "\n"
  end

  def write(part1:Object=nil, part2:Object=nil, part3:Object=nil, part4:Object=nil, part5:Object=nil):void
     @writer.write part1.toString if part1
     @writer.write part2.toString if part2
     @writer.write part3.toString if part3
     @writer.write part4.toString if part4
     @writer.write part5.toString if part5
  end

  def stop:void
    @writer.close if @writer
  end

  def getInferredType(node:Node):TypeFuture
    @typer.getInferredType(node)
  end

  def process_annotations(node:Annotated, visitor:AnnotationVisitor):void
    iterator = Annotated(node).annotations.iterator
    while iterator.hasNext
     anno = Annotation(iterator.next)
     @@log.finest "anno: #{anno} #{anno.type}"
     inferred = getInferredType(anno)
     next unless inferred
     anno_type = JVMType(inferred.resolve)
     if anno.values.size == 0
       visitor.visit(anno, anno_type, nil, nil)
     else
       values = anno.values.iterator
       while values.hasNext
         entry = HashEntry(values.next)
         key = Identifier(entry.key).identifier
         visitor.visit(anno, anno_type, key, entry.value)
       end
     end
    end
  end

  def process_modifiers(node:Annotated, visitor:ModifierVisitor):void
    process_annotations node do |anno, anno_type, key, value|
      return unless "org.mirah.jvm.types.Modifiers".equals anno_type.name
      if "access".equals(key)
        access = Identifier(value).identifier
        visitor.visit(0, access)
      elsif "flags".equals(key)
        flag_values = Array(value).values.iterator
        while flag_values.hasNext
          id = Identifier(flag_values.next)
          visitor.visit(1, id.identifier)
        end
      else
        raise "unknown modifier entry: #{key} #{value}"
      end
    end
  end

end

class ClassStubWriter < StubWriter

  def self.initialize
    @@log = Logger.getLogger ClassStubWriter.class.getName
  end

  def initialize(ctx:JavaStubPlugin, node:ClassDefinition)
    super(ctx.typer )
    @dest_path = ctx.stub_dir
    @encoding = ctx.encoding
    @class_name = node.name.identifier
    @node = node
    @fields = []
    @methods = []
  end

  def set_package pckg:String
    @package = pckg
  end

  def add_method(node:MethodDefinition):void
    @methods.add MethodStubWriter.new @class_name, node, typer
  end

  def add_field(node:FieldDeclaration):void
    @fields.add FieldStubWriter.new node, typer
  end

  def generate:void
    start
    write_package
    write_definition
  ensure
    stop
  end

  def start:void
   if @dest_path == '*'
     self.writer = OutputStreamWriter.new(System.out, @encoding);
   else
     dest_dir = File.new @dest_path
     base = @package ?  @package.replace(".", File.separator) : '.'
     base_dir = File.new dest_dir, base
     base_dir.mkdirs unless base_dir.exists
     java_file = File.new base_dir, "#{@class_name}.java"
     java_file.delete  if java_file.exists
     @@log.fine "start writing #{java_file.getAbsolutePath}"
     self.writer = OutputStreamWriter.new(BufferedOutputStream.new(FileOutputStream.new(java_file)), @encoding);
     writeln("//Generated by Mirah stub plugin");
   end
  end

  def write_package:void
    writeln "package ", @package, ';' if @package
  end
#TODO implements, extends
  def write_definition:void
    writeln JavaDoc(@node.java_doc).value if @node.java_doc
    modifier = 'public'
    flags = []
    process_modifiers(@node) do |atype:int, value:String|
      if atype = 0
        modifier = value.toLowerCase
      end
      if atype = 1
        flags.add value.toLowerCase
      end
    end
    write modifier
    this = self
    flags.each { |f| this.write ' ', f }
    if @node.kind_of? InterfaceDeclaration
      write " interface "
    else
      write " class "
    end
    writeln @class_name, "{"
    write_fields
    write_methods
    write "}"
  end

  def write_fields:void
    sorted = @fields.sort do |field1:FieldStubWriter, field2:FieldStubWriter|
      field1.name.compareTo field2.name
     end

    sorted.each do |stub_writer:StubWriter|
      stub_writer.writer=writer
      stub_writer.generate
    end
  end

  def write_methods:void
    @methods.each do |stub_writer:StubWriter|
      stub_writer.writer=writer
      stub_writer.generate
    end
  end

end

class MethodStubWriter < StubWriter

  def self.initialize
    @@log = Logger.getLogger MethodStubWriter.class.getName
  end

  def initialize(class_name:String, node:MethodDefinition, typer:Typer)
    super(typer)
    @node = node
    @class_name = class_name
  end

  # TODO optional args
  # TODO modifier
  def generate:void
    type = MethodType(getInferredType(@node).resolve)
    @@log.fine "node:#{@node} type: #{type}"
    modifier = "public"
    flags = []
    static = @node.kind_of? StaticMethodDefinition
    this = self
    process_modifiers(Annotated(@node)) do |atype:int, value:String|
      # workaround for PRIVATE and PUBLIC annotations for class constants
      if atype == 0
       modifier = value.toLowerCase
      end
      if atype == 1
        if value == 'SYNTHETIC' || value == 'BRIDGE'
            this.writeln ' // ', value
        else
            flags.add value.toLowerCase
        end
      end
    end

    @@log.finest "access: #{modifier} modifier: #{flags}"

    return if type.name.endsWith 'linit>' and static

    writeln JavaDoc(@node.java_doc).value if @node.java_doc
    write ' ', modifier, ' '
    //constructor
    if type.name.endsWith 'linit>'
      write @class_name
    else
      write " static " if static
      flags.each { |f| write f, ' ' }
      write type.returnType, " ", type.name
    end

    write "("
    write_args
    write "){"
    write_body JVMType(type.returnType)
    writeln "}"
  end

  def write_args:void
    args = @node.arguments
    first = write_args(true, args.required)
    first = write_args(first, args.optional)
    if args.rest
      write_arg Node(args.rest)
      first = false
    end
    first = write_args(first, args.required2)
  end

  def write_args(first:boolean, iterable:Iterable):boolean
    iterator = iterable.iterator
    while iterator.hasNext
      write ',' unless first
      first = false
      write_arg Node(iterator.next)
    end
    first
  end

  def write_arg(arg:Node):void
    type = getInferredType(arg).resolve
    write  type.name, ' ' , Named(arg).name.identifier
  end

  def write_body(type:JVMType):void
    unless type.name.equals 'void'
      unless JVMTypeUtils.isPrimitive type
        write " return null; "
      else
        if 'boolean'.equals(type.name)
            write ' return false; '
        else
            write ' return 0; '
        end
      end
    end
  end
end

class FieldStubWriter < StubWriter

  def self.initialize
    @@log = Logger.getLogger MethodStubWriter.class.getName
  end

  def initialize(node:FieldDeclaration, typer:Typer)
    super(typer)
    @node = node
    @name = @node.name.identifier
  end

  def name
    @name
  end

  # TODO modifier
  def generate:void
    type = JVMType(getInferredType(@node).resolve)
    @@log.fine "node:#{@node} type: #{type}"
    modifier = "private"
    flags = []
    process_modifiers(Annotated(@node)) do |atype:int, value:String|
      # workaround for PRIVATE and PUBLIC annotations for class constants
      if atype == 0
       modifier = value.toLowerCase if !"PRIVATE".equals value
      end
      if atype == 1
        flags.add value.toLowerCase
      end
    end
    @@log.fine "access: #{modifier} modifier: #{flags}"

    write " ", modifier, " "
    iterator = flags.each { |f| write f, ' ' }
    writeln type.name, " ", name(), ";"
  end

end