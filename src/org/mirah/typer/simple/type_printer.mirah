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

package org.mirah.typer.simple

import org.mirah.typer.MethodType
import java.util.*
import org.mirah.typer.*
import mirah.lang.ast.*
import mirah.impl.MirahParser
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.FileInputStream
import java.io.PrintStream
import java.io.PrintWriter
import java.io.Writer

class PrintStreamAdapter < Writer
  def initialize(out:PrintStream)
    @out = out
  end
  
  def write(buf:char[], off:int, len:int)
    if off == 0 && len == buf.length
      @out.print(buf)
    else
      @out.print(String.new(buf, off, len))
    end
  end

  def write(str:String)
    @out.print(str)
  end
end

# Prints an AST along with its inferred types.
class TypePrinter < NodeScanner
  def initialize(typer:Typer)
    initialize(typer, System.out)
  end

  def initialize(typer:Typer, writer:PrintWriter)
    @indent = 0
    @typer = typer
    @args = Object[1]
    @args[0] = ""
    @out = writer
  end

  def initialize(typer:Typer, writer:PrintStream)
    initialize(typer, PrintWriter.new(PrintStreamAdapter.new(writer)))
  end

  def printIndent:void
    @out.printf("%#{@indent}s", @args) if @indent > 0
  end
  def enterDefault(node, arg)
    printIndent
    @out.print(node)
    type = @typer.getInferredType(node)
    if type
      @out.print ": #{type.resolve}"
    end
    @out.println
    @indent += 2
    true
  end
  def enterUnquote(node, arg)
    super(node, arg)
    if node.object
      if node.object.kind_of?(Node)
        Node(node.object).accept(self, arg)
      else
        printIndent
        @out.print node.object
        @out.println
      end
    end
    node.object.nil?
  end
  def exitDefault(node, arg)
    @indent -= 2
    nil
  end
end






class TypePrinter2 < NodeScanner
  def initialize(typer:Typer)
    initialize(typer, System.out)
  end
  def initialize(typer:Typer, writer:PrintWriter)
    @indent = 0
    @typer = typer
    @args = Object[1]
    @args[0] = ""
    @out = writer
    @lineLength = 0
  end

  def initialize(typer:Typer, writer:PrintStream)
    initialize(typer, PrintWriter.new(PrintStreamAdapter.new(writer)))
  end

  def incIndent: void
    @indent+=2
  end
  def decIndent: void
    @indent -= 2
    if @indent < 0
      @indent = 0
    end
  end
  def printIndent:void
    @lineLength+=@indent
    @out.printf("%#{@indent}s", @args) if @indent > 0
  end

  def exitClassDefinition(node, arg)
    @out.print "\n"
    decIndent
    printIndent
    @out.print "end\n"
  end

  def enterClassDefinition(node, arg)
    printClass node
    false
  end

  def enterClosureDefinition(node, arg)
    printClass node
    false
  end

  def enterConstructorDefinition(node, arg)
    enterMethodDefinition node, arg
  end

  def enterMethodDefinition(node, arg)
    type = @typer.getInferredType(node)
    
    printIndent if node.annotations_size > 0
    @out.print "$TODOAnnotations\n"  if node.annotations_size > 0
    printIndent
    @out.print "def "
    @out.print "(self.)" # if MethodType(type).isStatic
    @out.print node.name.identifier
    node.arguments.accept(self, arg)

    if type
      @out.print " # #{type.resolve}"
    end
    @out.println
    incIndent
    node.body.accept(self, arg)
    decIndent
    @out.println
    printIndent
    @out.print "end\n"
    false
  end

  def enterRequiredArgumentList(node, arg)
    true
  end

  def enterRequiredArgument(node, arg)
    printIndent
    @out.print " #{node.name.identifier}"
    @out.print ": #{node.type.typeref}" if node.type
    @out.print ", "
    type = @typer.getInferredType(node)
    if type
      @out.print " # #{type.resolve}\n"
    end
    
    false
  end

  def enterSelf(node, arg)
    @out.print "self"
    false
  end

  def enterOptionalArgumentList(node, arg)
    @out.print("<TODO optional args>") if node
    false
  end
  def enterFixnum(node, arg)
    @out.print(node.value)
    false
  end

  def enterCall(node, arg)
    node.target.accept(self, arg)
    # todo gather types
    @out.print(".")
    @out.print(node.name.identifier)
    if node.parameters && node.parameters_size > 0
      @out.print("(\n")
      printIndent
      node.parameters.accept(self, arg)
      @out.print("\n")
      printIndent
      @out.print(")")
    end
    if node.block
      @out.print(" ")
      node.block.accept(self, arg)
    else
      #@out.print("\n")
    end
    false
  end

  def enterArguments(arguments, arg)
    count = 0
    count += arguments.required.size  if arguments.required
    count += arguments.optional.size  if arguments.optional
    count += arguments.required2.size if arguments.required2
    count += 1 if arguments.rest
    if count > 0
      @out.print "(\n"
      incIndent
      true
    else
      @out.print "("
      false
    end
  end

  def exitArguments(node, arg)
    printIndent
    @out.print ")"
    incIndent
    nil
  end

  def enterFieldAccess(node, arg)
    @out.print "@#{node.name.identifier}"

    type = @typer.getInferredType(node)
    if type
      @out.print " # #{type.resolve}"
    end
    @out.println
    false
  end

  def enterFieldAssign(node, arg)
    @out.print "@#{node.name.identifier} ="

    type = @typer.getInferredType(node)
    if type
      @out.print " # #{type.resolve}"
    end
    @out.println
    node.value.accept self, arg
    false
  end
  
  def enterStringConcat(node, arg)
    @out.print "\""
    node.strings.accept self, arg
    @out.print "\""
    false
  end
  def enterStringEval(node, arg)
    @out.print '#{'
    node.value.accept self, arg
    @out.print '}'
    false
  end

  def enterStringPieceList(node, arg)
    true
  end
  def exitStringPieceList(node, arg)
    nil
  end
  def enterSimpleString(node, arg)
    @out.print "\"#{node.identifier}\""
    false
  end

  def enterConstant(node, arg)
    @out.print node.name.identifier
    false
  end

  def enterLocalAccess(node, arg)
    @out.print node.name.identifier
    false
  end

  def enterLocalAssignment(node, arg)
    @out.print "#{node.name.identifier} = "

    type = @typer.getInferredType(node)
    if type
      @out.print " # #{type.resolve}"
    end
    @out.println
    printIndent
    @out.print "  "
    node.value.accept self, arg
    false
  end

  def printClass node: ClassDefinition
    printIndent
    @out.print "$TODO Annotations"
    @out.println
    printIndent
    @out.print "class #{node.name.identifier}"
    @out.print "< #{node.superclass.typeref.name}" if node.superclass
    @out.print "\n"

    incIndent
    # unless node.interfaces.isEmpty
    if node.interfaces.size > 0
      node.interfaces.each do |iface: TypeName|
        printIndent
        @out.print "implements #{iface.typeref.name}\n"
      end
    end
    scan node.body
  end

  def enterDefault(node, arg)
    printIndent
    @out.print(node)
    type = @typer.getInferredType(node)
    if type
      @out.print " # #{type.resolve}"
    end
    @out.println
    incIndent
    true
  end
  def enterBoolean(node, arg)
    @out.print node.value
    false
  end
  def exitDefault(node, arg)
    decIndent
    nil
  end
  def enterUnquote(node, arg)
    super(node, arg)
    if node.object
      if node.object.kind_of?(Node)
        Node(node.object).accept(self, arg)
      else
        printIndent
        @out.print node.object
        @out.println
      end
    end
    node.object.nil?
  end
  def exitUnquote(node, arg)
    # don't dedent
  end

  def enterFieldDeclaration(node, arg)
    printIndent
    @out.print "$TODO Annotations"
    @out.println
    printIndent
    @out.print "!FieldDec(@#{'@' if node.isStatic}#{node.name.identifier}, type=#{node.type})!"
    @out.println
    false
  end
  def enterNodeList(node, arg)
    #usually are already a body of something, so no need to indent
    #incIndent
    # nodelists are often lists of statements, so print indents between their children
    node.size.times do |i|
      child = node.get(i)
      if child.kind_of? Noop
        next
      end
      @out.println
      printIndent
      res = child.accept(self, arg)
    end
    false
  end
  def exitNodeList(node, arg)
    #decIndent
    nil
  end
  
end

