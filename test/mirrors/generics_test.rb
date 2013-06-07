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

require 'java'
require 'test/unit'
require 'mirah'

class BaseMirrorsTest < Test::Unit::TestCase
  java_import 'java.util.HashSet'
  java_import 'org.mirah.jvm.mirrors.generics.Constraints'
  java_import 'org.mirah.jvm.mirrors.generics.TypeParameterInference'
  java_import 'org.mirah.jvm.mirrors.generics.TypeVariable'
  java_import 'org.mirah.jvm.mirrors.BaseType'
  java_import 'org.mirah.jvm.mirrors.NullType'
  java_import 'org.mirah.jvm.model.ArrayType'
  java_import 'org.jruby.org.objectweb.asm.Type'

  def setup
    @types = MirrorTypeSystem.new
  end

  def test_null
    a = NullType.new
    f = TypeVariable.new('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    TypeParameterInference.processArgument(a, ?=.ord, f, map)
    assert_equal(0, constraints.size)
    TypeParameterInference.processArgument(a, ?<.ord, f, map)
    assert_equal(0, constraints.size)
    TypeParameterInference.processArgument(a, ?>.ord, f, map)
    assert_equal(0, constraints.size)
  end

  def test_extends_variable
    a = @types.getStringType.resolve
    f = TypeVariable.new('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    TypeParameterInference.processArgument(a, ?<.ord, f, map)
    assert_equal(1, constraints.size)
    assert_equal(HashSet.new([a]), constraints.getSuper)
  end

  def test_extends_primitive
    a = @types.getFixnumType(1).resolve
    f = TypeVariable.new('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    TypeParameterInference.processArgument(a, ?<.ord, f, map)
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.lang.Integer', c.name
  end

  def test_extends_array
    a = @types.getArrayType(@types.getStringType.resolve)
    f = ArrayType.new(TypeVariable.new('S'))
    constraints = Constraints.new
    map = {'S' => constraints}
    TypeParameterInference.processArgument(a, ?<.ord, f, map)
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.lang.String', c.name
  end

  def test_extends_array_variable
    a = TypeVariable.new('T', @types.getArrayType(@types.getStringType.resolve))
    f = ArrayType.new(TypeVariable.new('S'))
    constraints = Constraints.new
    map = {'S' => constraints}
    TypeParameterInference.processArgument(a, ?<.ord, f, map)
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.lang.String', c.name
  end

end