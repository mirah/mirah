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

class GenericsTest < Test::Unit::TestCase
  java_import 'java.util.HashSet'
  java_import 'org.mirah.jvm.mirrors.generics.Constraints'
  java_import 'org.mirah.jvm.mirrors.generics.LubFinder'
  java_import 'org.mirah.jvm.mirrors.generics.TypeParameterInference'
  java_import 'org.mirah.jvm.mirrors.generics.TypeVariable'
  java_import 'org.mirah.jvm.mirrors.generics.TypeInvocation'
  java_import 'org.mirah.jvm.mirrors.generics.Wildcard'
  java_import 'org.mirah.jvm.mirrors.BaseType'
  java_import 'org.mirah.jvm.mirrors.NullType'
  java_import 'org.mirah.jvm.mirrors.MirrorTypeSystem'
  java_import 'org.mirah.jvm.model.ArrayType'
  java_import 'org.mirah.jvm.model.Cycle'
  java_import 'org.mirah.jvm.model.IntersectionType'
  java_import 'org.mirah.typer.BaseTypeFuture'
  java_import 'org.jruby.org.objectweb.asm.Type'

  def setup
    @types = MirrorTypeSystem.new
    @type_utils = Java::OrgMirahJvmModel::Types.new(@types)
    @tpi = TypeParameterInference.new(@type_utils)
  end

  def set(param)
    iterable = g('java.lang.Iterable', [param])
    collection = g('java.util.Collection', [param], nil, [iterable])
    g('java.util.Set', [param], nil, [collection])
  end

  def type(name)
    if name.kind_of?(String)
      @types.loadNamedType(name).resolve
    else
      name
    end
  end

  def g(name, params, superclass=nil, interfaces=nil)
    klass = type(name)
    superclass ||= klass.superclass
    if interfaces
      interfaces = interfaces.map do |x|
        future = BaseTypeFuture.new
        future.resolved(type(x))
        future
      end
    else
      interfaces = klass.interfaces
    end
    TypeInvocation.new(klass, superclass, interfaces, params)
  end

  def typevar(name, bounds="java.lang.Object")
    if bounds.kind_of?(String)
      bounds = type(bounds)
    end
    TypeVariable.new(@type_utils, name, bounds)
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
    map = {f => constraints}
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
    map = {f => constraints}
    @tpi.processArgument(a, ?<.ord, f, map)
    assert_equal(1, constraints.size)
    assert_equal(HashSet.new([a]), constraints.getSuper)
  end

  def test_extends_primitive
    a = @types.getFixnumType(1).resolve
    f = typevar('S')
    constraints = Constraints.new
    map = {f => constraints}
    @tpi.processArgument(a, ?<.ord, f, map)
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.lang.Integer', c.name
  end

  def test_extends_array
    a = @types.getArrayType(@types.getStringType.resolve)
    s = typevar('S')
    f = ArrayType.new(s)
    constraints = Constraints.new
    map = {s => constraints}
    @tpi.processArgument(a, ?<.ord, f, map)
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.lang.String', c.name
  end

  def test_extends_array_variable
    a = typevar('T', @types.getArrayType(@types.getStringType.resolve))
    s = typevar('S')
    f = ArrayType.new(s)
    constraints = Constraints.new
    map = {s => constraints}
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
    map = {s => constraints}

    f = set(ArrayType.new(s))

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
    map = {s => constraints}
    f = set(Wildcard.new(s))
    
    @tpi.processArgument(a, ?<.ord, f, map)
    # S <: String
    assert_equal(1, constraints.size, constraints.toString)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.lang.String', c.name
    

    # A = Set<Regex[]>
    a = set(@types.getArrayType((@types.getRegexType.resolve)))

    constraints = Constraints.new
    map = {s => constraints}

    @tpi.processArgument(a, ?<.ord, f, map)
    # S <: Regex[]
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.util.regex.Pattern[]', c.name, c.java_class

    # F = Set<? extends S[]>
    f = set(Wildcard.new(ArrayType.new(s)))
    constraints = Constraints.new
    map = {s => constraints}
    @tpi.processArgument(a, ?<.ord, f, map)

    # S <: Regex
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.util.regex.Pattern', c.name
    
    # A has a supertype Set<Regex[]>
    a = BaseType.new(Type.getType('LFooBar;'), 0, a)
    constraints = Constraints.new
    map = {s => constraints}
    @tpi.processArgument(a, ?<.ord, f, map)

    # S <: Regex
    assert_equal(1, constraints.size)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.util.regex.Pattern', c.name
  end

  def test_extends_f_and_a_are_generic_with_extends_wildcard
    # A = Set<? extends String>
    a = set(Wildcard.new(@types.getStringType.resolve))

    # F = Set<? extends S>
    s = typevar('S')
    constraints = Constraints.new
    map = {s => constraints}
    f = set(Wildcard.new(s))
    
    @tpi.processArgument(a, ?<.ord, f, map)
    # S <: String
    assert_equal(1, constraints.size, constraints.toString)
    c = constraints.getSuper.iterator.next
    assert_equal 'java.lang.String', c.name
  end

  def test_extends_f_has_super_a_not_wildcard
    # A has a supertype Set<String>
    string = @types.getStringType.resolve
    a = BaseType.new(Type.getType('LFooBar;'), 0, set(string))

    s = typevar('S')
    constraints = Constraints.new
    map = {s => constraints}

    # F = Set<? super S>
    f = set(Wildcard.new(nil, s))
    @tpi.processArgument(a, ?<.ord, f, map)

    # S >: String
    assert_constraints(constraints, :extends => [string])
  end

  def test_extends_f_has_super_a_has_extends
    # A has a supertype Set<? extends String>
    string = @types.getStringType.resolve
    a = BaseType.new(Type.getType('LFooBar;'), 0, set(Wildcard.new(string)))

    s = typevar('S')
    constraints = Constraints.new
    map = {s => constraints}

    # F = Set<? super S>
    f = set(Wildcard.new(nil, s))
    @tpi.processArgument(a, ?<.ord, f, map)

    # no constraints
    assert_constraints(constraints)
  end

  def test_extends_f_and_a_have_super
    # A has a supertype Set<? super String>
    string = @types.getStringType.resolve
    a = BaseType.new(Type.getType('LFooBar;'), 0, set(Wildcard.new(nil, string)))

    s = typevar('S')
    constraints = Constraints.new
    map = {s => constraints}

    # F = Set<? super S>
    f = set(Wildcard.new(nil, s))
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
    assert_equal(abstract_list, @tpi.findMatchingSupertype(array_list, abstract_list))
  end

  def test_equal_variable
    a = @types.getStringType.resolve
    f = typevar('S')
    constraints = Constraints.new
    map = {f => constraints}
    @tpi.processArgument(a, ?=.ord, f, map)
    assert_equal(1, constraints.size)
    assert_equal(HashSet.new([a]), constraints.getEqual)
  end


  def test_equal_array
    a = @types.getArrayType(@types.getStringType.resolve)
    s = typevar('S')
    f = ArrayType.new(s)
    constraints = Constraints.new
    map = {s => constraints}
    @tpi.processArgument(a, ?=.ord, f, map)
    assert_equal(1, constraints.size)
    c = constraints.getEqual.iterator.next
    assert_equal 'java.lang.String', c.name
  end

  def test_equal_array_variable
    a = typevar('T', @types.getArrayType(@types.getStringType.resolve))
    s = typevar('S')
    f = ArrayType.new(s)
    constraints = Constraints.new
    map = {s => constraints}
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
    map = {s => constraints}

    f = set(ArrayType.new(s))

    @tpi.processArgument(a, ?=.ord, f, map)

    # S = String
    assert_equal(1, constraints.size)
    c = constraints.getEqual.iterator.next
    assert_equal 'java.lang.String', c.name
  end

  def test_equal_f_and_a_are_generic_with_extends_wildcard
    # A = Set<? extends String>
    string = @types.getStringType.resolve
    a = set(Wildcard.new(string))

    # F = Set<? extends S>
    s = typevar('S')
    constraints = Constraints.new
    map = {s => constraints}
    f = set(Wildcard.new(s))
    
    @tpi.processArgument(a, ?=.ord, f, map)
    assert_constraints(constraints, :equal => [string])
    assert_equal(1, constraints.size, constraints.toString)
    c = constraints.getEqual.iterator.next
    assert_equal 'java.lang.String', c.name
    

    # A = Set<Regex[]>
    re = @types.getRegexType.resolve
    re_array = @types.getArrayType(re)
    a = set(Wildcard.new(re_array))

    constraints = Constraints.new
    map = {s => constraints}

    @tpi.processArgument(a, ?=.ord, f, map)
    # S = Regex[]
    assert_constraints(constraints, :equal => [re_array])

    # F = Set<? extends S[]>
    f = set(Wildcard.new(ArrayType.new(s)))
    constraints = Constraints.new
    map = {s => constraints}
    @tpi.processArgument(a, ?=.ord, f, map)

    # S = Regex
    assert_constraints(constraints, :equal => [re])
    
    # A has a supertype Set<Regex[]>
    a = BaseType.new(Type.getType('LFooBar;'), 0, a)
    constraints = Constraints.new
    map = {s => constraints}
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
    map = {s => constraints}
    f = set(Wildcard.new(s))
    
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
    map = {s => constraints}
    f = set(Wildcard.new(nil, s))
    
    @tpi.processArgument(a, ?=.ord, f, map)
    # No constraints
    assert_constraints(constraints)

    # A = Set<? super String>
    string = @types.getStringType.resolve
    a = set(Wildcard.new(nil, string))
    @tpi.processArgument(a, ?=.ord, f, map)

    # S = String
    assert_constraints(constraints, :equal => [string])
  end


  def test_super_variable
    a = @types.getStringType.resolve
    f = typevar('S')
    constraints = Constraints.new
    map = {f => constraints}
    @tpi.processArgument(a, ?>.ord, f, map)
    # T <: A
    assert_constraints(constraints, :extends => [a])
  end

  def test_super_array
    a = @types.getArrayType(@types.getStringType.resolve)
    s = typevar('S')
    f = ArrayType.new(s)
    constraints = Constraints.new
    map = {s => constraints}
    @tpi.processArgument(a, ?>.ord, f, map)
    assert_constraints(constraints, :extends => [a.getComponentType])
  end

  def test_super_array_variable
    string = @types.getStringType.resolve
    a = typevar('T', @types.getArrayType(string))
    s = typevar('S')
    f = ArrayType.new(s)
    constraints = Constraints.new
    map = {s => constraints}
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
    map = {s => constraints}

    f = set(ArrayType.new(s))

    @tpi.processArgument(a, ?>.ord, f, map)

    # S = String
    assert_constraints(constraints, :equal => [string])

    # A = Set<? extends String>
    a = set(Wildcard.new(string))

    # F has supertype Set<String>
    f = BaseType.new(Type.getType("LFooBar;"), 0, set(s))
    constraints = Constraints.new
    map = {s => constraints}
    @tpi.processArgument(a, ?>.ord, f, map)
    assert_constraints(constraints, :extends => [string])

    # A = Set<? super String>
    a = set(Wildcard.new(nil, string))
    constraints = Constraints.new
    map = {s => constraints}
    @tpi.processArgument(a, ?>.ord, f, map)
    assert_constraints(constraints, :super => [string])
  end

  def test_super_f_and_a_are_generic_with_extends_wildcard
    # A = Set<? extends String>
    string = @types.getStringType.resolve
    a = set(Wildcard.new(string))

    # F = Set<? extends S>
    s = typevar('S')
    constraints = Constraints.new
    map = {s => constraints}
    f = set(Wildcard.new(s))

    @tpi.processArgument(a, ?>.ord, f, map)
    assert_constraints(constraints, :extends => [string])

    # A = Set<Regex[]>
    re = @types.getRegexType.resolve
    re_array = @types.getArrayType(re)
    a = set(Wildcard.new(re_array))

    constraints = Constraints.new
    map = {s => constraints}

    @tpi.processArgument(a, ?>.ord, f, map)
    # S = Regex[]
    assert_constraints(constraints, :extends => [re_array])

    # F = Set<? extends S[]>
    f = set(Wildcard.new(ArrayType.new(s)))
    constraints = Constraints.new
    map = {s => constraints}
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
    map = {s => constraints}
    f = set(Wildcard.new(s))

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
    map = {s => constraints}
    f = set(Wildcard.new(nil, s))

    @tpi.processArgument(a, ?>.ord, f, map)
    # No constraints
    assert_constraints(constraints)

    # A = Set<? super String>
    string = @types.getStringType.resolve
    a = set(Wildcard.new(nil, string))
    @tpi.processArgument(a, ?>.ord, f, map)

    # S = String
    assert_constraints(constraints, :super => [string])
  end

  def test_multi_generic
    klass = BaseType.new(Type.getType("LFooBar;"), 0, nil)
    string = @types.getStringType.resolve
    a = TypeInvocation.new(klass, klass.superclass, klass.interfaces,
        [string, string, string])
    
    r = typevar('R')
    s = typevar('S')
    t = typevar('T')
    
    f = TypeInvocation.new(klass, klass.superclass, klass.interfaces,
        [r, Wildcard.new(s), Wildcard.new(nil, t)])
    rc = Constraints.new
    sc = Constraints.new
    tc = Constraints.new
    map = {r => rc, s => sc, t => tc}
    @tpi.processArgument(a, ?<.ord, f, map)
    assert_constraints(rc, :equal => [string])
    assert_constraints(sc, :super => [string])
    assert_constraints(tc, :extends => [string])
  end

  def test_cycle
    klass = BaseType.new(Type.getType("LFooBar;"), 0, nil)
    cycle = Cycle.new
    a = TypeInvocation.new(klass, klass.superclass, klass.interfaces, [cycle])
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
    t = IntersectionType.new([type('java.io.Serializable'),
                              type('java.lang.CharSequence')])
    e = @type_utils.erasure(t)
    assert_equal(type('java.io.Serializable'), e, e.toString)
    t = IntersectionType.new([type('java.io.Serializable'),
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

  def test_type_invocation
    a = set(type('java.lang.String'))
    b = type('java.util.Set')
    assert(b.isSupertypeOf(a))
    assert(!a.isSupertypeOf(b))
    assert(b.isSupertypeOf(b))
    assert(b.isSameType(b))
    assert(!b.isSameType(a))
    assert(!a.isSameType(b))
    
    c = set(type('java.lang.CharSequence'))
    assert(c.isSupertypeOf(a))
    assert(!a.isSupertypeOf(c))
    assert(!c.isSameType(a))
    
    d = g('java.lang.Iterable', [type('java.lang.CharSequence')])
    puts "Go go gadget test!"
    assert(d.isSupertypeOf(a))
    assert(d.isSupertypeOf(c))
    assert(!c.isSupertypeOf(d))
    assert(!a.isSupertypeOf(d))
  end
end