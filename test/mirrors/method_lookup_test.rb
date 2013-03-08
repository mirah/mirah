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

require 'test/unit'
require 'mirah'

class BaseMethodLookupTest <  Test::Unit::TestCase
  java_import 'org.mirah.jvm.mirrors.MirrorTypeSystem'
  java_import 'org.mirah.jvm.mirrors.BaseType'
  java_import 'org.mirah.jvm.mirrors.MethodLookup'
  java_import 'org.mirah.jvm.mirrors.FakeMember'
  java_import 'org.mirah.jvm.types.MemberKind'
  java_import 'org.mirah.typer.simple.SimpleScope'
  java_import 'org.mirah.typer.BaseTypeFuture'
  java_import 'org.mirah.typer.ErrorType'
  java_import 'org.jruby.org.objectweb.asm.Opcodes'
  java_import 'org.jruby.org.objectweb.asm.Type'

  def setup
    @types = MirrorTypeSystem.new
    @scope = SimpleScope.new
  end

  def jvmtype(internal_name, flags=0, superclass=nil)
    BaseType.new(Type.getObjectType(internal_name), flags, superclass || wrap('Ljava/lang/Object;'))
  end

  def wrap(descriptor)
    wrap_type(Type.getType(descriptor))
  end

  def wrap_type(type)
    @types.wrap(type).resolve
  end

  def make_method(tag, flags=-1)
    FakeMember.create(@types, tag, flags)
  end
end

class MethodLookupTest < BaseMethodLookupTest
  def test_object_supertype
    main_future = @types.getMainType(nil, nil)
    object = @types.getSuperClass(main_future).resolve
    main = main_future.resolve
    assert(MethodLookup.isSubType(main, main))
    assert(MethodLookup.isSubType(main, object))
    assert_false(MethodLookup.isSubType(object, main))
    error = ErrorType.new([['Error']])
    assert(MethodLookup.isSubType(error, main))
    assert(MethodLookup.isSubType(main, error))
  end

  # TODO interfaces
  def check_supertypes(type, *supertypes)
    supertypes.each do |supertype|
      assert_block("Expected #{type} < #{supertype}") do
        MethodLookup.isSubType(type, supertype)
      end
    end
  end
  
  def check_not_supertypes(type, *supertypes)
    supertypes.each do |supertype|
      assert_block("Expected !(#{type} < #{supertype})") do
        !MethodLookup.isSubType(type, supertype)
      end
    end
  end
  
  def test_primitive_supertypes
    double = wrap('D')
    float = wrap('F')
    long = wrap('J')
    int = wrap('I')
    short = wrap('S')
    char = wrap('C')
    byte = wrap('B')
    bool = wrap('Z')
    check_supertypes(double, double)
    check_not_supertypes(double, float, long, int, short, char, byte, bool)
    check_supertypes(float, double, float)
    check_not_supertypes(float, long, int, short, char, byte, bool)
    check_supertypes(long, double, float, long)
    check_not_supertypes(long, int, short, char, byte, bool)
    check_supertypes(int, double, float, long, int)
    check_not_supertypes(int, short, char, byte, bool)
    check_supertypes(short, double, float, long, int, short)
    check_not_supertypes(short, char, byte, bool)
    check_supertypes(char, double, float, long, int, char)
    check_not_supertypes(char, byte, bool)
    check_supertypes(byte, double, float, long, int, short)
    check_not_supertypes(byte, char, bool)
    check_supertypes(bool, bool)
    check_not_supertypes(bool, double, float, long, int, short, char, byte)
  end

  def test_subtype_comparison
    double = wrap('D')
    int = wrap('I')
    short = wrap('S')
    assert_equal(0.0, MethodLookup.subtypeComparison(double, double))
    assert_equal(0.0, MethodLookup.subtypeComparison(int, int))
    assert_equal(1.0, MethodLookup.subtypeComparison(int, double))
    assert_equal(-1.0, MethodLookup.subtypeComparison(double, int))
    assert_equal(-1.0, MethodLookup.subtypeComparison(int, short))
    assert_equal(1.0, MethodLookup.subtypeComparison(short, int))
    
    main = @types.getMainType(nil, nil).resolve
    assert_equal(0.0, MethodLookup.subtypeComparison(main, main))
    assert(MethodLookup.subtypeComparison(double, main).nan?)
    assert(MethodLookup.subtypeComparison(main, int).nan?)
  end

  def test_pickMostSpecific
    m = MethodLookup.pickMostSpecific([make_method('@I.()V'), make_method('@Z.()V')])
    # Both ambiguous, one should be picked but it doesn't matter which
    assert_kind_of(FakeMember, m)
    
    expected = make_method('Z.()V')
    methods = [expected, make_method('@I.()V'), make_method('@S.()V')].shuffle
    assert_same(expected, MethodLookup.pickMostSpecific(methods))
  end

  def test_getPackage
    assert_equal("", MethodLookup.getPackage(jvmtype('Foo')))
    assert_equal("java/lang", MethodLookup.getPackage(wrap('Ljava/lang/String;')))
    assert_equal("java/util", MethodLookup.getPackage(wrap('Ljava/util/Map$Entry;')))
  end

  def visibility_string(flags)
    if 0 != (flags & Opcodes.ACC_PUBLIC)
      return :public
    elsif 0 != (flags & Opcodes.ACC_PROTECTED)
      return :protected
    elsif 0 != (flags & Opcodes.ACC_PRIVATE)
      return :private
    else
      return :'package private'
    end
  end

  def assert_visible(type, flags, visible, invisible=[])
    visible.each do |t|
      accessibility_assertion(type, flags, t, true)
    end
    invisible.each do |t|
      accessibility_assertion(type, flags, t, false)
    end
  end

  def set_self_type(type)
    future = BaseTypeFuture.new
    future.resolved(type)
    @scope.selfType_set(future)
  end

  def accessibility_assertion(a, flags, b, expected)
    assert_block "Expected #{visibility_string(flags)} #{a} #{expected ? '' : ' not '} visible from #{b}" do
      set_self_type(b)
      actual = MethodLookup.isAccessible(a, flags, @scope, nil)
      actual == expected
    end
  end

  def test_isAccessible
    object = wrap('Ljava/lang/Object;')
    string = wrap('Ljava/lang/String;')
    foo = jvmtype('Foo')
    assert_visible(object, Opcodes.ACC_PUBLIC, [object, string, foo])
    assert_visible(object, Opcodes.ACC_PROTECTED, [object, string, foo])
    assert_visible(object, Opcodes.ACC_PRIVATE, [object], [string, foo])
    assert_visible(object, 0, [object, string], [foo])
    assert_visible(foo, Opcodes.ACC_PRIVATE, [foo], [object, string])
    assert_visible(foo, Opcodes.ACC_PROTECTED, [foo], [object, string])
    assert_visible(string, Opcodes.ACC_PROTECTED, [string, object], [foo])  # visible to same package
    assert_visible(string, 0, [string, object], [foo])
  end

  def assert_methods_visible(methods, type, expected_visible)
    methods_desc = methods.inspect
    expected_invisible = methods - expected_visible
    set_self_type(type)
    invisible = MethodLookup.removeInaccessible(methods, @scope, nil)
    assert_equal(expected_invisible.map {|m| m.toString}, invisible.map {|m| m.toString})
    assert_equal(expected_visible.map {|m| m.toString}, methods.map {|m| m.toString})
    # TODO: fix protected usage. e.g. Foo can call Object.clone() through a foo instance, but not any Object.
  end

  def test_removeInaccessible
    # test method from an inaccessible class
    methods = [make_method("Ljava/lang/AbstractStringBuilder;.(I)V"), make_method("Ljava/lang/StringBuilder;.(I)V")]
    assert_methods_visible(methods, wrap('Ljava/util/Map;'), [methods[1]])

    # test inaccessible method
    methods = [make_method("Ljava/lang/Object;.()V", Opcodes.ACC_PRIVATE), make_method("Ljava/lang/String;.()V")]
  end

  def test_gatherMethods
    methods = MethodLookup.gatherMethods(wrap('Ljava/lang/String;'), 'toString')
    assert_equal(2, methods.size)

    declaring_classes = Set.new(methods.map {|m| m.declaringClass})
    assert_equal(Set.new([wrap('Ljava/lang/Object;'), wrap('Ljava/lang/String;')]), declaring_classes)
  end

  def test_findMethod
    set_self_type(jvmtype('Foo'))
    type = MethodLookup.findMethod(@scope, wrap('Ljava/lang/String;'), 'toString', [], nil).resolve
    assert(!type.isError)
    assert_nil(MethodLookup.findMethod(@scope, wrap('Ljava/lang/String;'), 'foobar', [], nil))
    type = MethodLookup.findMethod(@scope, wrap('Ljava/lang/Object;'), 'registerNatives', [], nil).resolve
    assert(type.isError)
    assert_equal('Cannot access java.lang.Object.registerNatives() from Foo', type.message[0][0])
    type = MethodLookup.findMethod(@scope, wrap('Ljava/lang/Object;'), 'clone', [], nil).resolve
    assert(type.isError)
    assert_equal('Cannot access java.lang.Object.clone() from Foo', type.message[0][0])
    # TODO test ambiguous
    # TODO check calling instance method from static scope.
  end
end

class CompareSpecificityTest < BaseMethodLookupTest
  def test_same_method
    m = 'I.(I)V'
    assert_specificity_equal(m, m)
  end

  def assert_more_specific(a, b)
    assert_specificity(a, b, 1.0)
    assert_specificity(b, a, -1.0)
  end

  def assert_less_specific(a, b)
    assert_more_specific(b, a)
  end

  def assert_specificity_equal(a, b)
    assert_specificity(a, b, 0.0)
    assert_specificity(b, a, 0.0)
  end

  def assert_ambiguous(a, b)
    nan = 0.0 / 0.0
    assert_specificity(a, b, nan)
    assert_specificity(b, a, nan)
  end

  def assert_specificity(a, b, value)
    actual = MethodLookup.compareSpecificity(make_method(a), make_method(b))
    assert_block "Expected compareSpecificity(#{a.inspect}, #{b.inspect}) = #{value} but was #{actual}" do
      if value.nan?
        actual.nan?
      else
        actual == value
      end
    end
  end

  def test_target
    a = 'I.()V'
    b = 'S.()V'
    
    assert_more_specific(b, a)
  end

  def test_target_with_same_args
    a = 'I.(II)V'
    b = 'S.(II)V'
    
    assert_more_specific(b, a)
  end

  def test_ambiguous_target
    # if the target is ambiguous the result should be equal
    assert_specificity_equal('Z.()V', 'I.()V')
    assert_specificity_equal('Z.(I)V', 'I.(I)V')
    assert_specificity_equal('Z.(II)V', 'I.(II)V')

    # unless the arguments are different
    assert_ambiguous('Z.(S)V', 'I.(I)V')
    assert_ambiguous('Z.(I)V', 'I.(S)V')
  end

  def test_arguments
    assert_more_specific('I.(S)V',  'I.(I)V')
    assert_more_specific('I.(SS)V', 'I.(II)V')
    assert_more_specific('I.(SI)V', 'I.(II)V')
    assert_more_specific('I.(IS)V', 'I.(II)V')
  end

  def test_ambiguous_arguments
    assert_ambiguous('I.(S)V', 'I.(Z)V')
    assert_ambiguous('I.(S)V', 'S.(Z)V')
    assert_ambiguous('S.(S)V', 'I.(Z)V')
  end

  def test_return_type_ignored
    a = 'I.()I'
    b = 'I.()S'
    c = 'C.()D'
    assert_specificity_equal(a, b)
    assert_more_specific(c, a)
    assert_more_specific(c, b)
  end
end

class FindMaximallySpecificTest < BaseMethodLookupTest
  def find_maximally_specific(method_tags)
    methods = {}
    method_tags.each do |m|
      method = make_method(m)
      methods[method] = m
    end
    result = MethodLookup.findMaximallySpecific(methods.keys)
    result.map {|m| methods[m] || m}
  end

  def assert_most_specific(expected, methods)
    assert_maximal([expected], methods)
  end

  def assert_maximal(expected, methods)
    actual = find_maximally_specific(methods)
    assert_equal(Set.new(expected), Set.new(actual))
  end
  
  def test_single_method
    m = 'I.()V'
    assert_most_specific(m, [m])
  end

  def test_more_specific
    a = 'I.(I)V'
    b = 'I.(S)V'
    assert_most_specific(b, [a, b])
  end

  def test_ambiguous
    a = 'I.(II)V'
    b = 'I.(SI)V'
    c = 'I.(IS)V'
    assert_maximal([b, c], [a, b, c])
  end

  def test_all_abstract
    a = 'I.(II)V'
    b = '@I.(SI)V'
    c = '@Z.(SI)V'
    result = find_maximally_specific([a, b, c])
    # either b or c should be picked.
    begin
      assert_equal([b], result)
    rescue
      assert_equal([c], result)
    end
  end

  def test_one_not_abstract
    a = 'I.(SI)V'
    b = '@I.(SI)V'
    c = '@Z.(SI)V'
    assert_most_specific(a, [a, b, c])
  end
end

class Phase1Test < BaseMethodLookupTest
  def phase1(methods, params)
    methods = MethodLookup.phase1(methods.map{|m| make_method(m)}, params.map{|p| wrap(p)})
    methods.map {|m| m.toString } if methods
  end

  def test_no_match
    assert_nil(phase1([], ['I']))
  end

  def test_simpe_match
    assert_equal(['I.()V'], phase1(['I.()V'], []))
    assert_equal(['I.(I)V'], phase1(['I.(I)V'], ['I']))
  end

  def test_arity
    assert_equal(['I.(SI)V'], phase1(['I.(S)V', 'I.(SI)V', 'I.(SII)V'], ['S','I']))
  end

  def test_ambiguous
    assert_equal(Set.new(%w(I.(SI)V I.(IS)V)),
                 Set.new(phase1(%w(I.(SI)V I.(IS)V), %w(S S))))
  end

  def test_ambiguity_resolution
    assert_equal(['I.()V'], phase1(%w(@Z.()V I.()V), []))
  end
end