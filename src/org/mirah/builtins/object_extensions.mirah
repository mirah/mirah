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

import org.mirah.macros.anno.ExtensionsRegistration

$ExtensionsRegistration[['java.lang.Object']]
class ObjectExtensions

  macro def ==(node)
    # During the transition, alias == to === inside equals method definitions
    mdef = MethodDefinition(@call.findAncestor(MethodDefinition.class))
    if mdef && mdef.name.identifier.equals("equals")
      if @call.target.kind_of?(Self) || node.kind_of?(Self)
        System.out.println("WARNING: == is now an alias for Object#equals(), === is now used for identity.\nThis use of == with self in equals() definition may cause a stack overflow in next release!#{mdef.position.source.name}:")
        source = @mirah.typer.sourceContent(mdef)
        s = source.split("\n")
        # last end has right whitespace, but def doesn't
        whitespace = s[s.length - 1].substring(0, s[s.length - 1].indexOf("end"))
        System.out.println("#{whitespace}#{source}")
        return quote {`@call.target` === `node`}
      end
    end

    left  = gensym
    right = gensym
    quote do
      `left`  = `@call.target`
      `right` = `node`
       if `left` === nil
         `right` === nil
       else
         `left`.equals `right`
       end
    end
  end

  ## TODO change != so that it does the below intrinsically.
  macro def !=(node)
    quote { !(`@call.target` == `node`)}
  end
  
  macro def tap(block:Block)
    x = gensym
    quote do
      `x` = `@call.target`
      `block.arguments.required(0).name.identifier` = `x`
      `block.body`
      `x`
    end
  end

  macro def puts(node)
    quote {System.out.println(` [node] `)}
  end
  macro def self.puts(node)
    quote {System.out.println(` [node] `)}
  end

  macro def puts()
    quote {System.out.println()}
  end
  macro def self.puts()
    quote {System.out.println()}
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

  # Casts the target of the call to the type_name.
  macro def as!(type_name: TypeName)
    Cast.new(type_name, @call.target)
  end

  macro def self.transient(s:SimpleString)
    FieldAnnotationRequest.new(s,nil,[Annotation.new(SimpleString.new('org.mirah.jvm.types.Modifiers'), [
      HashEntry.new(SimpleString.new('flags'), Array.new([SimpleString.new("TRANSIENT")]))
    ])])
  end

  macro def self.final(s:SimpleString,v:Fixnum)
    FieldAnnotationRequest.new(s,v,[Annotation.new(SimpleString.new('org.mirah.jvm.types.Modifiers'), [
      HashEntry.new(SimpleString.new('flags'), Array.new([SimpleString.new("FINAL")]))
    ])])
  end

  macro def self.static_field(s:SimpleString,v:Fixnum)
    field_assign = FieldAssign.new(s,v,[]) # trigger generation of the field, v is actually ignored if the field becomes static final
    field_assign.isStatic = true
    field_assign
  end
  
  macro def self.static_final(s:SimpleString,v:Fixnum)
    quote do
      final(`s`,`v`)
      static_field(`s`,`v`)
    end
  end
  
  macro def self.native(mdef:MethodDefinition)
    anno = Annotation.new(@call.name.position, Constant.new(SimpleString.new('org.mirah.jvm.types.Modifiers')),
                          [HashEntry.new(SimpleString.new('flags'), Array.new([SimpleString.new('NATIVE')]))])
    mdef.annotations.add(anno)
    mdef.setParent(nil)
    mdef
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

  macro def self.synchronized(mthd:MethodDefinition)
    anno = Annotation.new(@call.name.position, Constant.new(SimpleString.new('org.mirah.jvm.types.Modifiers')),
                          [HashEntry.new(SimpleString.new('flags'), Array.new([SimpleString.new('SYNCHRONIZED')]))])
    mthd.annotations.add(anno)
    mthd.setParent(nil)
    mthd
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

  # "protected" on a list of methods
  macro def self.protected(methods_proxy:NodeList)
    import org.mirah.typer.ProxyNode
    import java.util.LinkedList
    work = LinkedList.new([methods_proxy])
    
    while !work.isEmpty
      node = work.poll
      if node.kind_of?(MethodDefinition)
        anno = Annotation.new(@call.name.position, Constant.new(SimpleString.new('org.mirah.jvm.types.Modifiers')),[HashEntry.new(SimpleString.new('access'), SimpleString.new('PROTECTED'))])
        MethodDefinition(node).annotations.add(anno)
      elsif node.kind_of?(ProxyNode)
        work.add(ProxyNode(node).get(0))
      elsif node.kind_of?(NodeList)
        list = NodeList(node)
        i = 0
        while i < list.size
          work.add(list.get(i))
          i+=1
        end
      end
    end
    methods_proxy.setParent(nil)
    methods_proxy
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
    SyntheticLambdaDefinition.new(@call.position, type, block)
  end

  macro def self.lambda(type:TypeName, block:Block)
    SyntheticLambdaDefinition.new(@call.position, type, block)
  end
end
