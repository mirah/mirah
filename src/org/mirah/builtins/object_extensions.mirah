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

package org.mirah.builtins

import mirah.lang.ast.*
import org.mirah.typer.ClosureBuilder
import org.mirah.typer.ErrorType
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.macros.anno.ExtensionsRegistration

$ExtensionsRegistration[['java.lang.Object']]
class ObjectExtensions

  macro def ==(node)
    # During the transition, alias == to === inside equals method definitions
    mdef = MethodDefinition(@call.findAncestor(MethodDefinition.class))
    if mdef && mdef.name.identifier.equals("equals")
      if @call.target.kind_of?(Self) || node.kind_of?(Self)
        message = "WARNING: == is now an alias for Object#equals(), === is now used for identity.\n" +
          "This use of == with self in equals() definition may cause a stack overflow in next release!"

        puts message
        puts "#{mdef.position.source.name}:"
        source = @mirah.typer.sourceContent(mdef)
        s = source.split("\n")
        # last end has right whitespace, but def doesn't
        whitespace = s[s.length - 1].substring(0, s[s.length - 1].indexOf("end"))
        puts whitespace + source
        return quote {`@call.target` === `node`}
      end
    end

    # TODO this doesn't work, but should
    #quote { `@call.target`.nil? && `node`.nil? || `@call.target` && `@call.target`.equals(`node`) }

    tmp = gensym
    quote { `tmp` = `@call.target`.nil? && `node`.nil?
            `tmp` || `@call.target` && `@call.target`.equals(`node`) }
  end

  ## TODO handle the negation st def == will be called
  macro def !=(node)
    # TODO this doesn't work, but should
    #quote { ( `@call.target`.nil? && `node`.nil? ) || !`@call.target`.equals(`node`) }

    quote { !(`@call.target` == `node`)}
  end

  macro def puts(node)
    quote {System.out.println(` [node] `)}
  end
  macro def self.puts(node)
    quote {System.out.println(` [node] `)}
  end

  macro def print(node)
    quote {System.out.print(` [node] `)}
  end
  macro def self.print(node)
    quote {System.out.print(` [node] `)}
  end
  macro def loop(block:Block)
    quote { while true do `block.body` end }
  end
  macro def self.loop(block:Block)
    quote { while true do `block.body` end }
  end

  macro def self.abstract(klass:ClassDefinition)
    anno = Annotation.new(@call.name.position, Constant.new(SimpleString.new('org.mirah.jvm.types.Modifiers')),
                          [HashEntry.new(SimpleString.new('flags'), Array.new([SimpleString.new('ABSTRACT')]))])
    klass.annotations.add(anno)
    klass.setParent(nil)
    klass
  end

  macro def self.abstract(mdef:MethodDefinition)
    anno = Annotation.new(@call.name.position, Constant.new(SimpleString.new('org.mirah.jvm.types.Modifiers')),
                          [HashEntry.new(SimpleString.new('flags'), Array.new([SimpleString.new('ABSTRACT')]))])
    mdef.annotations.add(anno)
    mdef.setParent(nil)
    mdef
  end

  macro def self.protected(mthd:MethodDefinition)
    anno = Annotation.new(@call.name.position, Constant.new(SimpleString.new('org.mirah.jvm.types.Modifiers')),
                          [HashEntry.new(SimpleString.new('access'), SimpleString.new('PROTECTED'))])
    mthd.annotations.add(anno)
    mthd.setParent(nil)
    mthd
  end
  
  macro def self.private(mthd:MethodDefinition)
    anno = Annotation.new(@call.name.position, Constant.new(SimpleString.new('org.mirah.jvm.types.Modifiers')),
                          [HashEntry.new(SimpleString.new('access'), SimpleString.new('PRIVATE'))])
    mthd.annotations.add(anno)
    mthd.setParent(nil)
    mthd
  end
  
  macro def self.package_private(mthd:MethodDefinition)
    anno = Annotation.new(@call.name.position, Constant.new(SimpleString.new('org.mirah.jvm.types.Modifiers')),
                          [HashEntry.new(SimpleString.new('access'), SimpleString.new('DEFAULT'))])
    mthd.annotations.add(anno)
    mthd.setParent(nil)
    mthd
  end

  macro def self.attr_accessor(hash:Hash)
    args = [hash]
    quote do
      attr_reader `args`
      attr_writer `args`
    end
  end
  
  macro def self.attr_reader(hash:Hash)
    methods = NodeList.new
    i = 0
    size = hash.size
    while i < size
      e = hash.get(i)
      i += 1
      method = quote do
        def `e.key`:`e.value`  #`
          @`e.key`
        end
      end
      methods.add(method)
    end
    methods
  end
  
  macro def self.attr_writer(hash:Hash)
    methods = NodeList.new
    i = 0
    size = hash.size
    while i < size
      e = hash.get(i)
      i += 1
      name = "#{Identifier(e.key).identifier}_set"
      method = quote do
        def `name`(value:`e.value`):void  #`
          @`e.key` = value
        end
      end
      methods.add(method)
    end
    methods
  end

  macro def lambda(type:TypeName, block:Block)
  # TODO, just create a SyntheticLambdaDefinition that the ClosureBuilder picks up
    builder = ClosureBuilder.new(@mirah.typer)
    scope = @mirah.typer.scoper.getScope(@call)
    resolved = @mirah.type_system.get(scope, type.typeref).resolve
    # TODO, do something better than this
    raise "can't build lambda for #{type} #{resolved}" if resolved.kind_of? ErrorType
    builder.prepare(block, resolved)
  end

  macro def self.lambda(type:TypeName, block:Block)
    builder = ClosureBuilder.new(@mirah.typer)
    scope = @mirah.typer.scoper.getScope(@call)
    resolved = @mirah.type_system.get(scope, type.typeref).resolve
    # TODO, do something better than this
    raise "can't build lambda for #{type} #{resolved}" if resolved.kind_of? ErrorType
    builder.prepare(block, resolved)
  end
end
