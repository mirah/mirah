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

import org.mirah.macros.anno.ExtensionsRegistration

$ExtensionsRegistration[['[]']]
class ArrayExtensions
  
  # Compares 2 arrays (using java::util::Arrays.equals()).
  #
  # The arrays are equal if
  # 1. they have the same size and
  # 2. each pair of the elements of the arrays with the same index satisfies one of these rules:
  #   1. both are null, or
  #   2. the element of the left array is an Object and that object's #equals() methods returns true given the element of the right array, or
  #   3. the element of the left array is a primitive type (except double and float) and it equals to the element of the right array, or
  #   4. the element of the left array is a double and new Double(d1).equals(new Double(d2)) holds if d1 is the element of the left array and d2 is the element of the right array, or
  #   5. the element of the left array is a float  and new Float(f1).equals(new Float(f2))   holds if f1 is the element of the left array and f2 is the element of the right array.
  #
  # Note that the basetype of each array does not need to be equal for the arrays to be considered equal.
  macro def ==(other_array)
    quote do
      java::util::Arrays.equals(`call.target`,`other_array`)
    end
  end

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

  # Iterates over each element of the array, yielding each time both the element and the index in the array.
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
  
  #
  # int[].new(5)
  #
  macro def self.new(size)
    array_type    = call.target
    # basetype    = TypeName(arraytype).typeref.array_basetype
    array_typeref = TypeName(array_type).typeref
    basetype      = TypeRefImpl.new(array_typeref.name,false,array_typeref.isStatic,array_typeref.position)
    EmptyArray.new(call.position, basetype, size)
  end

  #
  # int[].new(5) do |i|
  #   i+3
  # end
  #
  macro def self.new(size,block:Block)
    if block.arguments && block.arguments.required_size() > 0
      counter = block.arguments.required(0)
      i = counter.name.identifier
    else
      i = gensym
    end
    res           = gensym
    arraytype     = @call.target
    quote do
      `res` = `arraytype`.new(`size`)
      `size`.times do |`i`|
#       `res`[`i`] = `block.body`
        `Call.new(quote{`res`},SimpleString.new('[]='),[quote{`i`},quote{`block.body`}],nil)`
      end
      `res`
    end
  end
  
  # Whether the array is empty (meaning: whether it contains 0 elements).
  # This is for compatibility with java.util.Collection#isEmpty.
  macro def isEmpty
    quote do
      `@call.target`.length == 0
    end
  end

  # The length of the array (meaning: the number of elements it contains).
  # This is for compatibility with java.util.Collection#size.
  macro def size
    quote do
      `@call.target`.length
    end
  end

  # View this array as a java.util.List.
  # Note that this is different from (a possible) #to_a in that #to_a returns a new List which is then independent of this array,
  # while #as_list returns a List which is linked to this array. Hence, changes to the List are reflected in this array, and vice versa.
  macro def as_list
    quote do
      java::util::Arrays.asList(`@call.target`)
    end
  end
  
  # Sort this array in-place, using the supplied Comparator.
  macro def sort!(comparator:Block)
    target = gensym
    quote do
      `target` = `@call.target`
#      java::util::Arrays.sort(`target`,&`comparator`)
      `Call.new(quote{java::util::Arrays},SimpleString.new('sort'),[quote{`target`}],comparator)`
      `target`
    end
  end

  # Return a new array which is a sorted version of this array, using the supplied Comparator.
  macro def sort(comparator:Block)
    array = gensym 
    quote do
      `array` = `@call.target`.dup
#     `array`.sort!(&`comparator`)
      `Call.new(quote{`array`},SimpleString.new('sort!'),[],comparator)`
    end
  end

  # Sort this array in-place.
  macro def sort!()
    quote do
      java::util::Arrays.sort(`@call.target`)
      `@call.target`
    end
  end

  # Return a new array which is a sorted version of this array.
  macro def sort()
    array = gensym 
    quote do
      `array` = `@call.target`.dup
      `array`.sort!()
    end
  end

  # Create a duplicate of this array.
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
