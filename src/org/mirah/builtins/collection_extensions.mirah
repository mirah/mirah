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

class CollectionExtensions
  # returns true if is empty
  # an alias for isEmpty
  macro def empty?
    quote { `@call.target`.isEmpty }
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

  # map to an array of the return type of the block
  macro def mapa(block:Block)
    type_future        = @mirah.typer.infer(block.body)
    # This code fails in case we cannot resolve the type at the time the macro is invoked
    # (e.g. in case the type is defined after the macro invocation).
    # We should modify the compiler to allow for a TypeFuture to be used as typeref instead.
    typeref            = TypeRefImpl.new(type_future.resolve.name,false,false,@call.target.position)

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
    
#  macro def to_a_complex(basetype) # just for complex types, maybe this implementation could be auto-choosen if the compiler can deduce that the type supplied is indeed a complex type
#    list  = gensym
#    quote do
#      `list` = `@call.target`
#      `list`.toArray(`basetype`[`list`.size])
#    end
#  end

  # convert this collection to a Java-style array
  macro def to_a(basetype) # for primitive types and complex types
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
end
