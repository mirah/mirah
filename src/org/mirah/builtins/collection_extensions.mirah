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

package org.mirah.builtins

import org.mirah.macros.anno.ExtensionsRegistration

$ExtensionsRegistration[['[]', 'java.util.Collection']]
class CollectionExtensions
  # returns true if is empty
  # an alias for isEmpty
  macro def empty?
    quote { `@call.target`.isEmpty }
  end

  # Append the supplied element to this collection. Return this collection.
  macro def <<(arg)
    target = gensym
    quote do
      `target` = `@call.target` 
      `target`.add(`arg`)
      `target` # return the target, such that we can chain "<<" operators one after another.
    end
  end

  macro def map(block:Block)
    x = if block.arguments && block.arguments.required_size() > 0
      block.arguments.required(0)
    else
      gensym
    end

    list = gensym
    result = gensym
    quote do
      `list` = `@call.target`
      `result` = java::util::ArrayList.new(`list`.size)
      `list`.each do |`x`|
        `result`.add(` [block.body] `)
      end
      `result`
    end
  end

  # Map to an array of the return type of the block.
  macro def mapa(block:Block)
    type_future = @mirah.typer.infer(block.body)
    typeref     = org::mirah::typer::TypeFutureTypeRef.new(type_future)

    x = if block.arguments && block.arguments.required_size() > 0
      block.arguments.required(0)
    else
      gensym
    end

    list = gensym
    result = gensym
    index  = gensym
    quote do
      `list` = `@call.target`
      `result` = `typeref`[`list`.size]
      `list`.each_with_index do |`x`,`index`|
        `Call.new(quote{`result`},SimpleString.new('[]='),[ quote { `index` } , quote { ` [block.body] ` } ],nil)`
      end
      `result`
    end
  end
  
  macro def select(block:Block)
    x      = block.arguments.required(0)
    list   = gensym
    result = gensym
    quote do
      `list`   = `@call.target`
      `result` = java::util::ArrayList.new(`list`.size)
      `list`.each do |`x`|
        if (` [block.body] `)
          `result`.add(`x.name.identifier`)
        end
      end
      `result`
    end
  end
  
  macro def join()
    b     = gensym
    list  = gensym
    entry = gensym
    quote do
      `list` = `@call.target`
      `b`    = StringBuilder.new
      `list`.each do |`entry`|
        `b`.append(`entry`)
      end
      `b`.toString
    end
  end
  
  # Create a String which consists of the String representation of each element of this Collection, interleaved with the supplied separator.
  #
  #   [1,2,3].join("+") => "1+2+3"
  macro def join(separator)
    b     = gensym
    list  = gensym
    entry = gensym
    nonfirst = gensym
    quote do
      `list` = `@call.target`
      `b`    = StringBuilder.new
      `nonfirst` = false
      `list`.each do |`entry`|
        if `nonfirst`
          `b`.append(`separator`)
        else
          `nonfirst` = true
        end
        `b`.append(`entry`)
      end
      `b`.toString
    end
  end
    
#  macro def to_array_complex(basetype) # just for complex types, maybe this implementation could be auto-choosen if the compiler can deduce that the type supplied is indeed a complex type
#    list  = gensym
#    quote do
#      `list` = `@call.target`
#      `list`.toArray(`basetype`[`list`.size])
#    end
#  end

  # Convert this Collection to a Java-style array. You have to supply the base-type of the array, currently.
  #
  #   [1,2,3,4].to_array(int)
  macro def to_array(basetype) # for primitive types and complex types
    list  = gensym
    res   = gensym
    value = gensym
    index = gensym
    quote do
      `list` = `@call.target`
      `res`  = `basetype`[`list`.size]
      `list`.each_with_index do |`value`,`index`|
        `Call.new(quote{`res`},SimpleString.new('[]='),[ quote { `index` } , quote { ` value ` } ],nil)`
      end
      `res`
    end
  end
  
  # Returns first element of the list.
  # In case the list is empty, an instance of java.lang.IndexOutOfBoundsException is raised. 
  macro def first!()
    quote do
      `call.target`[0]
    end
  end
  
  # Returns last  element of the list.
  # In case the list is empty, an instance of java.lang.IndexOutOfBoundsException is raised. 
  macro def last!()
    quote do
      `call.target`[`call.target`.size()-1] # This is inefficient for java.util.LinkedList.
    end
  end
  
  # Returns first element of the list.
  # If there is no first element, return nil.
  # This macro does not work for Java-arrays of primitive types.
  macro def first()
    list = gensym
    quote do
      `list` = `call.target`
      if !`list`.isEmpty
        `list`[0]
      else
        nil
      end
    end
  end
  
  # Returns last  element of the list.
  # If there is no first element, return nil.
  # This macro does not work for Java-arrays of primitive types.
  macro def last()
    list = gensym
    quote do
      `list` = `call.target`
      if !`list`.isEmpty
        `list`[`list`.size()-1] # This is inefficient for java.util.LinkedList.
      else
        nil
      end
    end
  end
end
