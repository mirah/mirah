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
require 'java'
require ENV.fetch('MIRAHC_JAR',File.expand_path("../../../dist/mirahc.jar",__FILE__))
require File.expand_path("../../jvm/new_backend_test_helper",__FILE__)

class GenericsTest < Test::Unit::TestCase
  java_import 'java.util.HashSet'
  java_import 'javax.lang.model.util.Types'
  java_import 'org.objectweb.asm.Type'

  java_import 'org.mirah.jvm.mirrors.BaseType'
  java_import 'org.mirah.jvm.mirrors.generics.Constraints'
  java_import 'org.mirah.jvm.mirrors.generics.LubFinder'
  java_import 'org.mirah.jvm.mirrors.generics.TypeInvocation'
  java_import 'org.mirah.jvm.mirrors.generics.GenericsCapableSignatureReader'
  java_import 'org.mirah.jvm.mirrors.generics.TypeParameterInference'
  java_import 'org.mirah.jvm.mirrors.generics.TypeVariable'
  java_import 'org.mirah.jvm.mirrors.generics.Wildcard'
  java_import 'org.mirah.jvm.mirrors.MirrorTypeSystem'
  java_import 'org.mirah.jvm.mirrors.NullType'
  java_import 'org.mirah.jvm.model.Cycle'
  java_import 'org.mirah.jvm.model.IntersectionType'
  java_import 'org.mirah.typer.BaseTypeFuture'

  def setup
    super
    @types = MirrorTypeSystem.new
    @type_utils = @types.context.get(Types.java_class)
    @tpi = TypeParameterInference.new(@type_utils)
    @object = type('java.lang.Object')
  end

  def set(param)
    g('java.util.Set', [param])
  end

  def type(name)
    if name.kind_of?(String)
      @types.loadNamedType(name).resolve
    else
      name
    end
  end

  def g(name, params)
    klass = future(name)
    params = params.map {|x| future(x)}
    @types.parameterize(klass, params, {}).resolve
  end

  def future(x)
    future = BaseTypeFuture.new
    future.resolved(type(x))
    future
  end

  def typevar(name, bounds="java.lang.Object")
    if bounds.kind_of?(String)
      bounds = type(bounds)
    end
    TypeVariable.new(@types.context, name, bounds)
  end

  def assert_constraints(constraints, expected={})
    expected_constraints = Constraints.new
    if expected[:super]
      expected[:super].each {|x| expected_constraints.addSuper(x)}
    end
    if expected[:equal]
      expected[:equal].each {|x| expected_constraints.addEqual(x)}
    end
    if expected[:extends]
      expected[:extends].each {|x| expected_constraints.addExtends(x)}
    end
    assert_equal(expected_constraints.toString, constraints.toString)
  end

  def test_null
    a = NullType.new
    f = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?=.ord, f, map)
    assert_equal(0, constraints.size)
    @tpi.processArgument(a, ?<.ord, f, map)
    assert_equal(0, constraints.size)
    @tpi.processArgument(a, ?>.ord, f, map)
    assert_equal(0, constraints.size)
  end

  def test_extends_variable
    a = @types.getStringType.resolve
    f = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?<.ord, f, map)
    assert_equal(1, constraints.size)
    assert_equal(HashSet.new([a]), constraints.getSuper)
  end

  def test_extends_primitive
    a = @types.getFixnumType(1).resolve
    f = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?<.ord, f, map)
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.lang.Integer', c.name
  end

  def test_extends_array
    a = @types.getArrayType(@types.getStringType.resolve)
    s = typevar('S')
    f = @types.getArrayType(s)
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?<.ord, f, map)
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.lang.String', c.name
  end

  def test_extends_array_variable
    a = typevar('T', @types.getArrayType(@types.getStringType.resolve))
    s = typevar('S')
    f = @types.getArrayType(s)
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?<.ord, f, map)
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.lang.String', c.name
  end

  def test_extends_generic_no_wildcards
    # A = Set<String[]>
    a = set(@types.getArrayType(@types.getStringType.resolve))

    # F = Set<S[]>
    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}

    f = set(@types.getArrayType(s))

    @tpi.processArgument(a, ?<.ord, f, map)

    # S = String
    assert_equal(1, constraints.size)
    c = constraints.getEqual.iterator.next
    assert_equal 'java.lang.String', c.name
  end

  def test_extends_f_generic_with_extends_wildcard_a_not_wildcard
    # A = Set<String>
    a = set(@types.getStringType.resolve)

    # F = Set<? extends S>
    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    f = set(@type_utils.getWildcardType(s, nil))
    
    @tpi.processArgument(a, ?<.ord, f, map)
    # S <: String
    assert_equal(1, constraints.size, constraints.toString)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.lang.String', c.name
    

    # A = Set<Regex[]>
    a = set(@types.getArrayType((@types.getRegexType.resolve)))

    constraints = Constraints.new
    map = {'S' => constraints}

    @tpi.processArgument(a, ?<.ord, f, map)
    # S <: Regex[]
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.util.regex.Pattern[]', c.name, c.java_class

    # F = Set<? extends S[]>
    f = set(@type_utils.getWildcardType(@types.getArrayType(s), nil))
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?<.ord, f, map)

    # S <: Regex
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.util.regex.Pattern', c.name
    
    # A has a supertype Set<Regex[]>
    a = BaseType.new(nil, Type.getType('LFooBar;'), 0, a)
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?<.ord, f, map)

    # S <: Regex
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.util.regex.Pattern', c.name
  end

  def test_extends_f_and_a_are_generic_with_extends_wildcard
    # A = Set<? extends String>
    a = set(@type_utils.getWildcardType(@types.getStringType.resolve, nil))

    # F = Set<? extends S>
    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    f = set(@type_utils.getWildcardType(s, nil))
    
    @tpi.processArgument(a, ?<.ord, f, map)
    # S <: String
    assert_equal(1, constraints.size, constraints.toString)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.lang.String', c.name
  end

  def test_extends_f_has_super_a_not_wildcard
    # A has a supertype Set<String>
    string = @types.getStringType.resolve
    a = BaseType.new(nil, Type.getType('LFooBar;'), 0, set(string))

    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}

    # F = Set<? super S>
    f = set(@type_utils.getWildcardType(nil, s))
    @tpi.processArgument(a, ?<.ord, f, map)

    # S >: String
    assert_constraints(constraints, :extends => [string])
  end

  def test_extends_f_has_super_a_has_extends
    # A has a supertype Set<? extends String>
    string = @types.getStringType.resolve
    a = BaseType.new(nil, Type.getType('LFooBar;'), 0, set(@type_utils.getWildcardType(string, nil)))

    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}

    # F = Set<? super S>
    f = set(@type_utils.getWildcardType(nil, s))
    @tpi.processArgument(a, ?<.ord, f, map)

    # no constraints
    assert_constraints(constraints)
  end

  def test_extends_f_and_a_have_super
    # A has a supertype Set<? super String>
    string = @types.getStringType.resolve
    a = BaseType.new(nil, Type.getType('LFooBar;'), 0, set(@type_utils.getWildcardType(nil, string)))

    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}

    # F = Set<? super S>
    f = set(@type_utils.getWildcardType(nil, s))
    @tpi.processArgument(a, ?<.ord, f, map)

    # S >: String
    assert_constraints(constraints, :extends => [string])
  end

  def test_null_type
    assert_not_nil(@type_utils)
    t = @type_utils.getNullType
    assert_not_nil(t)
    assert_equal 'NULL', t.getKind.name
  end

  def test_directSupertypes
    set = @types.loadNamedType('java.util.Set').resolve
    assert_equal(['java.util.Collection'], @type_utils.directSupertypes(set).map {|x| x.name})
    
    string = @types.loadNamedType('java.lang.String').resolve
    assert_equal(
        ['java.lang.Object', 'java.io.Serializable', 'java.lang.Comparable', 'java.lang.CharSequence'],
         @type_utils.directSupertypes(string).map {|x| x.name})
  end

  def test_findMatchingSupertype
    string = @types.loadNamedType('java.lang.String').resolve
    assert_equal(string, @tpi.findMatchingSupertype(string, string))
    cs = @types.loadNamedType('java.lang.CharSequence').resolve
    assert_equal(cs, @tpi.findMatchingSupertype(string, cs))
    abstract_list = @types.loadNamedType('java.util.AbstractList').resolve
    assert_nil(@tpi.findMatchingSupertype(string, abstract_list))
    
    array_list = @types.loadNamedType('java.util.ArrayList').resolve
    assert_equal(abstract_list.name, @tpi.findMatchingSupertype(array_list, abstract_list).name)
  end

  def test_equal_variable
    a = @types.getStringType.resolve
    f = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?=.ord, f, map)
    assert_equal(1, constraints.size)
    assert_equal(HashSet.new([a]), constraints.getEqual)
  end


  def test_equal_array
    a = @types.getArrayType(@types.getStringType.resolve)
    s = typevar('S')
    f = @types.getArrayType(s)
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?=.ord, f, map)
    assert_equal(1, constraints.size)
    c = constraints.getEqual.iterator.next
    assert_equal 'java.lang.String', c.name
  end

  def test_equal_array_variable
    a = typevar('T', @types.getArrayType(@types.getStringType.resolve))
    s = typevar('S')
    f = @types.getArrayType(s)
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?=.ord, f, map)
    assert_equal(1, constraints.size)
    c = constraints.getEqual.iterator.next
    assert_equal 'java.lang.String', c.name
  end

  def test_equal_generic_no_wildcards
    # A = Set<String[]>
    a = set(@types.getArrayType(@types.getStringType.resolve))

    # F = Set<S[]>
    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}

    f = set(@types.getArrayType(s))

    @tpi.processArgument(a, ?=.ord, f, map)

    # S = String
    assert_equal(1, constraints.size)
    c = constraints.getEqual.iterator.next
    assert_equal 'java.lang.String', c.name
  end

  def test_equal_f_and_a_are_generic_with_extends_wildcard
    # A = Set<? extends String>
    string = @types.getStringType.resolve
    a = set(@type_utils.getWildcardType(string, nil))

    # F = Set<? extends S>
    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    f = set(@type_utils.getWildcardType(s, nil))
    
    @tpi.processArgument(a, ?=.ord, f, map)
    assert_constraints(constraints, :equal => [string])
    assert_equal(1, constraints.size, constraints.toString)
    c = constraints.getEqual.iterator.next
    assert_equal 'java.lang.String', c.name
    

    # A = Set<Regex[]>
    re = @types.getRegexType.resolve
    re_array = @types.getArrayType(re)
    a = set(@type_utils.getWildcardType(re_array, nil))

    constraints = Constraints.new
    map = {'S' => constraints}

    @tpi.processArgument(a, ?=.ord, f, map)
    # S = Regex[]
    assert_constraints(constraints, :equal => [re_array])

    # F = Set<? extends S[]>
    f = set(@type_utils.getWildcardType(@types.getArrayType(s), nil))
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?=.ord, f, map)

    # S = Regex
    assert_constraints(constraints, :equal => [re])
    
    # A has a supertype Set<Regex[]>
    a = BaseType.new(nil, Type.getType('LFooBar;'), 0, a)
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?=.ord, f, map)

    # No constraint
    assert_constraints(constraints)
  end

  def test_equal_f_generic_with_extends_wildcard_a_not_wildcard
    # A = Set<String>
    a = set(@types.getStringType.resolve)

    # F = Set<? extends S>
    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    f = set(@type_utils.getWildcardType(s, nil))
    
    @tpi.processArgument(a, ?=.ord, f, map)
    # No constraints
    assert_constraints(constraints)
  end

  def test_equal_f_generic_with_super
    # A = Set<String>
    a = set(@types.getStringType.resolve)

    # F = Set<? super S>
    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    f = set(@type_utils.getWildcardType(nil, s))
    
    @tpi.processArgument(a, ?=.ord, f, map)
    # No constraints
    assert_constraints(constraints)

    # A = Set<? super String>
    string = @types.getStringType.resolve
    a = set(@type_utils.getWildcardType(nil, string))
    @tpi.processArgument(a, ?=.ord, f, map)

    # S = String
    assert_constraints(constraints, :equal => [string])
  end


  def test_super_variable
    a = @types.getStringType.resolve
    f = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?>.ord, f, map)
    # T <: A
    assert_constraints(constraints, :extends => [a])
  end

  def test_super_array
    a = @types.getArrayType(@types.getStringType.resolve)
    s = typevar('S')
    f = @types.getArrayType(s)
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?>.ord, f, map)
    assert_constraints(constraints, :extends => [a.getComponentType])
  end

  def test_super_array_variable
    string = @types.getStringType.resolve
    a = typevar('T', @types.getArrayType(string))
    s = typevar('S')
    f = @types.getArrayType(s)
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?>.ord, f, map)
    assert_constraints(constraints, :extends => [string])
  end

  def test_super_generic_no_wildcards
    # A = Set<String[]>
    string = @types.getStringType.resolve
    str_array = a = set(@types.getArrayType(string))

    # F = Set<S[]>
    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}

    f = set(@types.getArrayType(s))

    @tpi.processArgument(a, ?>.ord, f, map)

    # S = String
    assert_constraints(constraints, :equal => [string])

    # A = Set<? extends String>
    a = set(@type_utils.getWildcardType(string, nil))

    # F has supertype Set<String>
    f = BaseType.new(nil, Type.getType("LFooBar;"), 0, set(s))
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?>.ord, f, map)
    assert_constraints(constraints, :extends => [string])

    # A = Set<? super String>
    a = set(@type_utils.getWildcardType(nil, string))
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?>.ord, f, map)
    assert_constraints(constraints, :super => [string])
  end

  def test_super_f_and_a_are_generic_with_extends_wildcard
    # A = Set<? extends String>
    string = @types.getStringType.resolve
    a = set(@type_utils.getWildcardType(string, nil))

    # F = Set<? extends S>
    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    f = set(@type_utils.getWildcardType(s, nil))

    @tpi.processArgument(a, ?>.ord, f, map)
    assert_constraints(constraints, :extends => [string])

    # A = Set<Regex[]>
    re = @types.getRegexType.resolve
    re_array = @types.getArrayType(re)
    a = set(@type_utils.getWildcardType(re_array, nil))

    constraints = Constraints.new
    map = {'S' => constraints}

    @tpi.processArgument(a, ?>.ord, f, map)
    # S = Regex[]
    assert_constraints(constraints, :extends => [re_array])

    # F = Set<? extends S[]>
    f = set(@type_utils.getWildcardType(@types.getArrayType(s), nil))
    constraints = Constraints.new
    map = {'S' => constraints}
    @tpi.processArgument(a, ?>.ord, f, map)

    # S = Regex
    assert_constraints(constraints, :extends => [re])
  end

  def test_super_f_generic_with_extends_wildcard_a_not_wildcard
    # A = Set<String>
    a = set(@types.getStringType.resolve)

    # F = Set<? extends S>
    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    f = set(@type_utils.getWildcardType(s, nil))

    @tpi.processArgument(a, ?>.ord, f, map)
    # No constraints
    assert_constraints(constraints)
  end

  def test_super_f_generic_with_super
    # A = Set<String>
    a = set(@types.getStringType.resolve)

    # F = Set<? super S>
    s = typevar('S')
    constraints = Constraints.new
    map = {'S' => constraints}
    f = set(@type_utils.getWildcardType(nil, s))

    @tpi.processArgument(a, ?>.ord, f, map)
    # No constraints
    assert_constraints(constraints)

    # A = Set<? super String>
    string = @types.getStringType.resolve
    a = set(@type_utils.getWildcardType(nil, string))
    @tpi.processArgument(a, ?>.ord, f, map)

    # S = String
    assert_constraints(constraints, :super => [string])
  end

  def test_multi_generic
    klass = BaseType.new(nil, Type.getType("LFooBar;"), 0, nil)
    string = @types.getStringType
    a = TypeInvocation.new(nil, klass, future(klass.superclass), klass.interfaces,
        [string, string, string], {})
    
    r = typevar('R')
    s = typevar('S')
    t = typevar('T')
    
    f = TypeInvocation.new(nil, klass, future(klass.superclass), klass.interfaces,
        [future(r), future(@type_utils.getWildcardType(s, nil)), future(@type_utils.getWildcardType(nil, t))], {})
    rc = Constraints.new
    sc = Constraints.new
    tc = Constraints.new
    map = {'R' => rc, 'S' => sc, 'T' => tc}
    @tpi.processArgument(a, ?<.ord, f, map)
    string = string.resolve
    assert_constraints(rc, :equal => [string])
    assert_constraints(sc, :super => [string])
    assert_constraints(tc, :extends => [string])
  end

  def test_cycle
    klass = BaseType.new(nil, Type.getType("LFooBar;"), 0, nil)
    cycle = Cycle.new
    a = TypeInvocation.new(nil, klass, future(klass.superclass), klass.interfaces, [future(cycle)], {})
    cycle.target_set(a)
    assert_equal("FooBar<FooBar<FooBar<...>>>", a.toString)
  end

  def test_erasure
    t = @types.getFixnumType(0).resolve
    assert_same(t, @type_utils.erasure(t))
    t = @types.getStringType.resolve
    assert_same(t, @type_utils.erasure(t))
    t = @types.getArrayType(t)
    assert_equal(t.toString, @type_utils.erasure(t).toString)
    t = set(t)
    assert_equal("java.util.Set<java.lang.String[]>", t.toString)
    e = @type_utils.erasure(t)
    assert_not_same(t, e)
    assert_equal([], e.type_arguments.to_a)
    assert_equal("java.util.Set", e.toString)
    t = @type_utils.getArrayType(t)
    assert_equal("java.util.Set<java.lang.String[]>[]", t.toString)
    e = @type_utils.erasure(t)
    assert_equal("java.util.Set[]", e.toString)
    t = IntersectionType.new(@types.context,
                             [type('java.io.Serializable'),
                              type('java.lang.CharSequence')])
    e = @type_utils.erasure(t)
    assert_equal(type('java.io.Serializable'), e, e.toString)
    t = IntersectionType.new(@types.context,
                             [type('java.io.Serializable'),
                              type('java.util.AbstractMap')])
    e = @type_utils.erasure(t)
    assert_equal(type('java.util.AbstractMap'), e)
    t = typevar("S")
    e = @type_utils.erasure(t)
    assert_equal(type('java.lang.Object'), e, e.toString)
    t = typevar("S", 'java.lang.Iterable')
    e = @type_utils.erasure(t)
    assert_equal(type('java.lang.Iterable'), e, e.toString)
  end

  def test_generic_array_supertype
    s = set(type('java.lang.String'))
    a = @types.getArrayType(s)
    assert_equal('java.util.Set<java.lang.String>[]', a.toString)
    supertypes = a.directSupertypes
    assert_equal('[java.lang.Object, java.util.Set[], java.util.Collection<java.lang.String>[]]',
                 supertypes.toString)

  end

  def test_type_invocation
    a = set(type('java.lang.String'))
    b = type('java.util.Set')
    assert(b.isSupertypeOf(a))
    # Set<E> isn't really a supertype of Set, but we allow it to make unchecked conversion work.
    # assert(!a.isSupertypeOf(b))
    assert(b.isSupertypeOf(b))
    assert(b.isSameType(b))
    assert(!b.isSameType(a))
    assert(!a.isSameType(b))
    
    c = set(type('java.lang.CharSequence'))
    assert(c.isSupertypeOf(a))
    assert(!a.isSupertypeOf(c))
    assert(!c.isSameType(a))
    
    d = g('java.lang.Iterable', [type('java.lang.CharSequence')])
    assert(d.isSupertypeOf(a))
    assert(d.isSupertypeOf(c))
    assert(!c.isSupertypeOf(d))
    assert(!a.isSupertypeOf(d))
  end

  def test_erased_supertypes
    lub = LubFinder.new(@types.context)
    t = @types.getStringType.resolve
    m = lub.erasedSupertypes(t)
    assert_equal(
      ['java.lang.String', 'java.lang.Object',
       'java.io.Serializable', 'java.lang.Comparable',
       'java.lang.CharSequence'
      ], m.key_set.map{|x| x.toString})
    
    t = set(t)
    m = lub.erasedSupertypes(t)
    assert_equal(
      ['java.util.Set', 'java.util.Collection',
       'java.lang.Iterable', 'java.lang.Object'
      ], m.key_set.map{|x| x.toString})
    assert_equal(
      ['[java.util.Set<java.lang.String>]',
       '[java.util.Collection<java.lang.String>]',
       '[java.lang.Iterable<java.lang.String>]',
       '[java.lang.Object]'
      ], m.values.map{|x| x.toString})
  end

  def test_raw_lub
    a = g('java.lang.Iterable', [type('java.lang.String')])
    b = a.erasure
    lub = LubFinder.new(@types.context)
    c = lub.leastUpperBound([a, b])
    assert_equal(b.toString, c.toString)
  end

  def test_minimizeErasedCandidates
    lub = LubFinder.new(@types.context)
    t = set(@types.getStringType.resolve)
    s = g('java.util.Collection', [type('java.lang.CharSequence')])
    candidates = lub.erasedCandidateSet([t, s])
    assert_equal(['java.util.Collection', 'java.lang.Iterable', 'java.lang.Object'],
                 candidates.key_set.map{|x| x.toString})
    lub.minimizeErasedCandidates(candidates.key_set)
    assert_equal(['java.util.Collection'],
                 candidates.key_set.map{|x| x.toString})
    candidates = HashSet.new(candidates.values.first.map {|x| x.toString})
    assert_equal(HashSet.new(
    ["java.util.Collection<java.lang.String>",
      "java.util.Collection<java.lang.CharSequence>"
    ]), candidates)
  end

  def test_lub
    finder = LubFinder.new(@types.context)
    string = type('java.lang.String')
    lub = finder.leastUpperBound([string])
    assert_equal(string, lub, lub.toString)

    cs = type('java.lang.CharSequence')
    lub = finder.leastUpperBound([string, cs])
    assert_equal(cs, lub, lub.toString)

    a = set(string)
    lub = finder.leastUpperBound([a, a])
    assert(a.isSameType(lub), lub.toString)

    b = g('java.lang.Iterable', [type('java.io.Serializable')])
    lub = finder.leastUpperBound([a, b])
    assert_equal('java.lang.Iterable<? extends java.io.Serializable>',
                 lub.toString)

    c = set(a)
    lub = finder.leastUpperBound([a, c])
    assert_equal('java.util.Set<?>', lub.toString)
  end

  def test_lub_cycle
    finder = LubFinder.new(@types.context)
    string = type('java.lang.String')
    integer = type('java.lang.Integer')
    lub = finder.leastUpperBound([string, integer])
    assert_match(/java\.lang\.Comparable<\? extends ...>/,
                 lub.toString)
  end

  def test_non_generic_type_with_generic_superclass
    string = @types.getStringType.resolve
    interfaces = string.interfaces.map {|x| x.resolve.toString}
    assert_equal(["java.lang.Comparable<java.lang.String>"],
                 interfaces.grep(/Comparable/))
  end
  
  def test_type_invoker_simple_signature
    invoker = invoker_for_signature('Ljava/lang/Object;')
    assert_equal(0,invoker.getFormalTypeParameters.size)
  end
  
  def test_type_invoker_array_as_type_parameter_signature
    invoker = invoker_for_signature('<T:Ljava/lang/Object;>Ljava/lang/Class<[TT;>;')
    assert_equal(1,invoker.getFormalTypeParameters.size)
  end
  
  def test_type_invoker_class_with_self_referential_bounds
    invoker = invoker_for_signature('<P:LAnotherClassWithSelfReferencingTypeParameter<TP;>;>Ljava/lang/Object;')
    assert_equal(1,invoker.getFormalTypeParameters.size)
  end
  
  def test_ClassWithSelfReferencingTypeParameter
    cls, = compile(%q[
      import org.foo.ClassWithSelfReferencingTypeParameter
      
      ClassWithSelfReferencingTypeParameter.new.foo.bar.baz
    ])
    assert_run_output("baz\n", cls)
  end
  
  def test_issue_417_npe
    omit_if JVMCompiler::JVM_VERSION.to_f < 1.8
    pend "fix NPE in generic inference" do
    cls, = compile(%q[
      import org.foo.TypeFixtureJava8
      import java.util.function.BiConsumer
      import java.util.Map
      import java.util.List

      class Issue417Test

         def initialize(filters:List, flags:int)
            @filters = filters
            @flags = flags
            @loader = TypeFixtureJava8.new
            @future = nil
         end

         def run():void
             @future = @loader.load(@filters, @flags)
         end

         def handle(block:BiConsumer):Issue417Test
            @future.whenComplete(block)
            self
         end

         def join():void
            @future.join
         end

      end
    ])
    end
  end
  
  def test_type_invoker_recursive_reference_signature
    omit_if JVMCompiler::JVM_VERSION.to_f < 1.8
    # Stream API is needed here
    invoker = invoker_for_signature('<T:Ljava/lang/Object;S::Ljava/util/stream/BaseStream<TT;TS;>;>Ljava/lang/Object;Ljava/lang/AutoCloseable;')
    assert_equal(2,invoker.getFormalTypeParameters.size)
  end
  
  def invoker_for_signature(signature)
    context   = @types.context
    invoker   = GenericsCapableSignatureReader.new(context)
    invoker.read(signature)
    invoker
  end
end

