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

class ArrayExtensions
  macro def each(block:Block)
    if block.arguments && block.arguments.required_size() > 0
      arg = block.arguments.required(0)
      x = arg.name.identifier
      type = arg.type if arg.type
    else
      x = gensym
      type = TypeName(nil)
    end
    array = gensym
    i = gensym

    getter = quote { `array`[`i`] }
    if type
      getter = Cast.new(type.position, type, getter)
    end

    quote do
      while `i` < `array`.length
        init {`array` = `@call.target`; `i` = 0}
        pre {`x` = `getter`}
        post {`i` = `i` + 1}
        `block.body`
      end
    end
  end

  macro def each_with_index(block:Block)
    arg = block.arguments.required(0)
    x = arg.name.identifier
    type = arg.type if arg.type
    i = block.arguments.required(1).name.identifier
    array = gensym

    getter = quote { `array`[`i`] }
    if type
      getter = Cast.new(type.position, type, getter)
    end

    quote do
      while `i` < `array`.length
        init {`array` = `@call.target`; `i` = 0}
        pre {`x` = `getter`}
        post {`i` = `i` + 1}
        `block.body`
      end
    end
  end
  
  macro def isEmpty
    quote do
      `@call.target`.length == 0
    end
  end

  macro def size
    quote do
      `@call.target`.length
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
      `result` = `typeref`[`list`.length]
      `list`.each_with_index do |`x`,`index`|
        `Call.new(quote{`result`},SimpleString.new('[]='),[ quote { `index` } , quote { ` [block.body] ` } ],nil)`
      end
      `result`
    end
  end
  
  macro def as_list
    quote do
      java::util::Arrays.asList(`@call.target`)
    end
  end
  
  macro def sort!(comparator:Block)
    target = gensym
    quote do
      `target` = `@call.target`
#      java::util::Arrays.sort(`target`,&`comparator`)
      `Call.new(quote{java::util::Arrays},SimpleString.new('sort'),[quote{`target`}],comparator)`
      `target`
    end
  end

  macro def sort(comparator:Block)
    array = gensym 
    quote do
      `array` = `@call.target`.dup
#     `array`.sort!(&`comparator`)
      `Call.new(quote{`array`},SimpleString.new('sort!'),[],comparator)`
    end
  end

  macro def sort!()
    quote do
      java::util::Arrays.sort(`@call.target`)
      `@call.target`
    end
  end

  macro def sort()
    array = gensym 
    quote do
      `array` = `@call.target`.dup
      `array`.sort!()
    end
  end

  macro def dup
    type_future        = @mirah.typer.infer(@call.target)
    # This code fails in case we cannot resolve the type at the time the macro is invoked
    # (e.g. in case the type is defined after the macro invocation).
    # We should modify the compiler to allow for a TypeFuture to be used as typeref instead.
    arraytype_name     = type_future.resolve.name
    arraytype_basename = arraytype_name.substring(0,arraytype_name.length-2) # remove trailing "[]", should be improved once mirah's array support is improved
    typeref            = TypeRefImpl.new(arraytype_basename,true,false,@call.target.position)
    
    Cast.new(@call.position,typeref,
      quote do
        `@call.target`.clone
      end
    )
  end

  macro def self.cast(array)
    Cast.new(@call.position, TypeName(@call.target), array)
  end
end
