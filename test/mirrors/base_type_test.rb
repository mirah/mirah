# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
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

require 'test_helper'

class BaseTypeTest < Test::Unit::TestCase
  java_import 'org.objectweb.asm.Type'
  java_import 'org.objectweb.asm.Opcodes'
  java_import 'org.mirah.jvm.mirrors.BaseType'
  java_import 'org.mirah.jvm.mirrors.VoidType'
  java_import 'org.mirah.jvm.mirrors.Member'
  java_import 'org.mirah.jvm.mirrors.MirrorTypeSystem'
  java_import 'org.mirah.jvm.types.MemberKind'
  java_import 'mirah.lang.ast.TypeRefImpl'

  def setup
    @types = MirrorTypeSystem.new
    @type = BaseType.new(@types.context, Type.getType("LFooBar;"), 0, nil)
    @void = VoidType.new
  end

  def type(name)
    @types.get(nil, TypeRefImpl.new(name, false, false, nil)).resolve
  end

  def test_tostring
    assert_equal("FooBar", @type.toString)
  end

  def test_assignableFrom
    object = type('java.lang.Object')
    map = type('java.util.Map')
    hashmap = type('java.util.HashMap')
    assert(object.assignableFrom(object))
    assert(object.assignableFrom(map))
    assert(object.assignableFrom(hashmap))
    assert(!map.assignableFrom(object))
    assert(map.assignableFrom(map))
    assert(map.assignableFrom(hashmap))
    assert(!hashmap.assignableFrom(object))
    assert(!hashmap.assignableFrom(map))
    assert(hashmap.assignableFrom(hashmap))
  end

  def test_primitive_widen
    int = type('int')
    long = type('long')
    assert_equal(int, int.widen(int))
    assert_equal(long, long.widen(long))
    assert_equal(long, int.widen(long))
    assert_equal(long, long.widen(int))
  end

  def test_object_widen
    object = type('java.lang.Object')
    map = type('java.util.Map')
    hashmap = type('java.util.HashMap')
    assert_equal(object, object.widen(object))
    assert_equal(object, object.widen(map))
    assert_equal(object, object.widen(hashmap))
    assert_equal(object, map.widen(object))
    assert_equal(map, map.widen(map))
    assert_equal(map, map.widen(hashmap))
    assert_equal(object, hashmap.widen(object))
    assert_equal(map, hashmap.widen(map))
    assert_equal(hashmap, hashmap.widen(hashmap))
    
    # TODO: test more complex widening, eg LinkedList.widen(ArrayList)
  end

  def test_box_widen
    object = type('java.lang.Object')
    int = type('int')
    map = type('java.util.Map')
    assert_equal(object, int.widen(map))
    assert_equal(object, map.widen(int))
  end

  def test_widen_void_to_map_is_error
    map = type('java.util.Map')
    assert(@void.widen(map).isError, @void.widen(map).to_s)
  end

  def test_widen_to_void_is_error
    map = type('java.util.Map')
    assert(map.widen(@void).isError, map.widen(@void).to_s)
  end

  def test_void_assignable_from_map
    map = type('java.util.Map')
    refute(@void.assignableFrom(map))
  end

  def test_map_assignable_from_void
    map = type('java.util.Map')
    refute(map.assignableFrom(@void))
  end
end