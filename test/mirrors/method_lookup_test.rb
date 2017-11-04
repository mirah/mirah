# Copyright (c) 2010-2014 The Mirah project authors. All Rights Reserved.
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
require 'java'
require ENV.fetch('MIRAHC_JAR',File.expand_path("../../../dist/mirahc.jar",__FILE__))

class BaseMethodLookupTest <  Test::Unit::TestCase
  java_import 'org.mirah.jvm.mirrors.MirrorTypeSystem'
  java_import 'org.mirah.jvm.mirrors.BetterScopeFactory'
  java_import 'org.mirah.jvm.mirrors.BaseType'
  java_import 'org.mirah.jvm.mirrors.MethodLookup'
  java_import 'org.mirah.jvm.mirrors.LookupState'
  java_import 'org.mirah.jvm.mirrors.FakeMember'
  java_import 'org.mirah.jvm.mirrors.Member'
  java_import 'org.mirah.jvm.mirrors.MetaType'
  java_import 'org.mirah.jvm.mirrors.MirrorProxy'
  java_import 'org.mirah.jvm.mirrors.NullType'
  java_import 'org.mirah.jvm.types.MemberKind'
  java_import 'org.mirah.typer.BaseTypeFuture'
  java_import 'org.mirah.typer.ErrorMessage'
  java_import 'org.mirah.typer.ErrorType'
  java_import 'org.mirah.typer.simple.SimpleScoper'
  java_import 'mirah.lang.ast.Script'
  java_import 'org.objectweb.asm.Opcodes'
  java_import 'org.objectweb.asm.Type'

  class FakeMirror < BaseType
    def initialize(desc, superclass=nil, flags=Opcodes.ACC_PUBLIC)
      super(nil, Type.getType(desc), flags, superclass)
      @fields = {}
    end

    def add_field(name, flags=Opcodes.ACC_PUBLIC)
      kind = if (flags & Opcodes.ACC_STATIC) == 0
        MemberKind::FIELD_ACCESS
      else
        MemberKind::STATIC_FIELD_ACCESS
      end
      @fields[name] = Member.new(flags, self, name, [], self, kind)
    end

    def getDeclaredField(name)
      @fields[name]
    end
  end

  def setup
    @types = MirrorTypeSystem.new
    @scope = new_scope
    @lookup = MethodLookup.new(@types.context)
  end

  def new_scope opts={}
    BetterScopeFactory.new.newScope(SimpleScoper.new(nil), opts[:context] || Script.new)
  end

  def jvmtype(internal_name, flags=0, superclass=nil)
    BaseType.new(@types.context, Type.getObjectType(internal_name), flags, superclass || wrap('Ljava/lang/Object;'))
  end

  def wrap(descriptor)
    wrap_type(Type.getType(descriptor))
  end

  def wrap_type(type)
    @types.wrap(type).resolve
  end

  def make_method(tag, flags=Opcodes.ACC_PUBLIC)
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

    error = ErrorType.new([ErrorMessage.new('Error')])

    assert(MethodLookup.isSubType(error, main))
    assert(MethodLookup.isSubType(main, error))
  end

  # TODO interfaces
  def check_supertypes(type, *supertypes)
    supertypes.each do |supertype|
      assert_block("Expected #{type} < #{supertype}") do
        MethodLookup.isSubType(type, supertype)
      end
      assert_block("Expected #{type}.assignableFrom(#{supertype})") do
        supertype.assignableFrom(type)
      end
    end
  end
  
  def check_not_supertypes(type, *supertypes)
    supertypes.each do |supertype|
      assert_block("Expected !(#{type} < #{supertype})") do
        !MethodLookup.isSubType(type, supertype)
      end
      assert_block("Expected #{type}.assignableFrom(#{supertype}) = false") do
        !supertype.assignableFrom(type)
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

  def array(desc)
    @types.getArrayType(wrap(desc))
  end

  def test_array_supertypes
    check_supertypes(array("I"),
                     array("I"),
                     wrap("Ljava/lang/Object;"),
                     wrap("Ljava/lang/Cloneable;"),
                     wrap("Ljava/io/Serializable;"))
    check_not_supertypes(array("I"), array("J"), array("S"), array("D"),
                         array("Ljava/lang/Object;"))
    check_supertypes(array("Ljava/util/Map;"),
                     wrap("Ljava/lang/Object;"),
                     wrap("Ljava/lang/Cloneable;"),
                     wrap("Ljava/io/Serializable;"),
                     array("Ljava/lang/Object;"),
                     array("Ljava/util/Map;"))
    check_supertypes(array("Ljava/util/HashMap;"),
                     wrap("Ljava/lang/Object;"),
                     wrap("Ljava/lang/Cloneable;"),
                     wrap("Ljava/io/Serializable;"),
                     array("Ljava/lang/Object;"),
                     array("Ljava/util/Map;"),
                     array("Ljava/io/Serializable;"),
                     array("Ljava/util/AbstractMap;"))
  end

  def test_null_subtype
    null = MirrorProxy.new(NullType.new)
    object = wrap("Ljava/lang/Object;")
    assert(MethodLookup.isSubType(null, object))
    assert(MethodLookup.isSubType(null, wrap("Ljava/lang/String;")))
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

  def test_boxing
    a = @types.getBooleanType.resolve
    b = @types.wrap(Type.getType('Ljava/lang/Boolean;')).resolve
    c = @types.getFixnumType(1).resolve

    assert(!MethodLookup.isSubType(a, b))
    assert(!MethodLookup.isSubType(b, a))
    assert(MethodLookup.isSubTypeWithConversion(a, b))
    assert(MethodLookup.isSubTypeWithConversion(b, a))
    assert(!MethodLookup.isSubTypeWithConversion(c, b))
    assert(!MethodLookup.isSubTypeWithConversion(b, c))
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

  def assert_visible(type, flags, visible, invisible=[], target=nil)
    visible.each do |t|
      accessibility_assertion(type, flags, t, true, target)
    end
    invisible.each do |t|
      accessibility_assertion(type, flags, t, false, target)
    end
  end

  def set_self_type(type)
    future = BaseTypeFuture.new
    future.resolved(type)
    @scope.selfType_set(future)
  end

  def accessibility_assertion(a, flags, b, expected, target=nil)
    assert_block "Expected #{visibility_string(flags)} #{a} #{expected ? '' : ' not '} visible from #{b}" do
      set_self_type(b)
      actual = MethodLookup.isAccessible(a, flags, @scope, target)
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
    
    # instance method from static scope
    assert_visible(object, Opcodes.ACC_PUBLIC, [], [object, foo],
                   MetaType.new(object))
  end

  def assert_methods_visible(methods, type, expected_visible)
    methods_desc = methods.inspect
    expected_invisible = methods - expected_visible
    set_self_type(type)
    invisible = @lookup.removeInaccessible(methods, @scope, nil)

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
    assert_methods_visible(methods, wrap('Ljava/util/Map;'), [methods[1]])
  end

  def test_gatherMethods
    methods = @lookup.gatherMethods(wrap('Ljava/lang/String;'), 'toString')
    assert_equal(3, methods.size)

    declaring_classes = Set.new(methods.map {|m| m.declaringClass})
    assert_equal(Set.new([wrap('Ljava/lang/Object;'),
                          wrap('Ljava/lang/String;'),
                          wrap('Ljava/lang/CharSequence;')]),
                 declaring_classes)
  end

  def test_method_splitting
    set_self_type(jvmtype('Foo'))
    methods = [make_method("Ljava/lang/Object;.()V", Opcodes.ACC_PRIVATE), make_method("Ljava/lang/String;.()V")]
    state = LookupState.new(@types.context, @scope, wrap('Ljava/lang/String;'), methods, nil)
    assert_equal("{potentials: 1 0 inaccessible: 1 0}", state.toString)
  end

  def test_search
    set_self_type(jvmtype('Foo'))
    methods = [make_method("Ljava/lang/Object;.()V")]
    state = LookupState.new(@types.context, @scope, wrap('Ljava/lang/String;'), methods, nil)
    state.search([], nil)
    assert_equal("{1 methods 0 macros 0 inaccessible}", state.toString)
    future = state.future(false)
    assert_not_nil(future)
    type = future.resolve
    assert(!type.isError)
    assert_equal("Ljava/lang/String;", type.returnType.asm_type.descriptor)
  end

  def test_findMethod
    set_self_type(jvmtype('Foo'))
    type = @lookup.findMethod(@scope, wrap('Ljava/lang/String;'), 'toString', [], nil, nil, false).resolve
    assert(!type.isError, type.toString)
    assert_nil(@lookup.findMethod(@scope, wrap('Ljava/lang/String;'), 'foobar', [], nil, nil, false))
    type = @lookup.findMethod(@scope, wrap('Ljava/lang/Object;'), 'registerNatives', [], nil, nil, false).resolve
    assert(type.isError)
    assert_equal('Cannot access java.lang.Object.registerNatives() from Foo', type.messages[0].message)
    pend "Can't tell the difference between 'super' random protected methods" do
      type = @lookup.findMethod(@scope, wrap('Ljava/lang/Object;'), 'clone', [], nil, nil, false).resolve
      assert(type.isError)
      assert_equal('Cannot access java.lang.Object.clone() from Foo', type.messages[0].message)
    end
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
    actual = MethodLookup.compareSpecificity(make_method(a), make_method(b), [nil, nil])
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
    result = MethodLookup.findMaximallySpecific(methods.keys, [nil, nil])
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
    methods = @lookup.phase1(methods.map{|m| make_method(m)}, params.map{|p| wrap(p)})
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

  def test_error_least_specific
    error_member = Member.new(
        Opcodes.ACC_PUBLIC, wrap('I'), 'foo', [ErrorType.new([ErrorMessage.new('Error')])], wrap('I'),
        MemberKind::METHOD)
    # The method should match
    assert_equal([error_member],
                 @lookup.phase1([error_member], [wrap('I')]).to_a)
    # And be least specific
    ok_member = make_method('I.(I)S')
    assert_equal([ok_member],
                 @lookup.phase1([error_member, ok_member], [wrap('I')]).to_a)
  end
end

class FieldTest < BaseMethodLookupTest
  def setup
    super
    @a = FakeMirror.new('LA;')
    @b = FakeMirror.new('LB;', @a)
    @scope = new_scope
    @selfType = BaseTypeFuture.new
    @selfType.resolved(@b)
    @scope.selfType_set(@selfType)
  end

  def test_gather_fields
    a_foo = @a.add_field("foo")
    a_bar = @a.add_field("bar")
    b_foo = @b.add_field("foo")
    foos = @lookup.gatherFields(@b, 'foo', []).to_a
 
    assert_equal([b_foo, a_foo], foos)
    assert_equal([a_bar], @lookup.gatherFields(@b, 'bar', []).to_a)
  end

  def test_find_super_field
    @a.add_field("foo")

    future = @lookup.findMethod(@scope, @b, 'foo', [], nil, nil, false)

    assert_equal("LA;", future.resolve.returnType.asm_type.descriptor)
  end

  def test_field_override
    @a.add_field("foo")
    @b.add_field("foo")

    future = @lookup.findMethod(@scope, @b, 'foo', [], nil, nil, false)

    assert_equal("LB;", future.resolve.returnType.asm_type.descriptor)
  end

  def test_inaccessible_overrides_accessible
    @selfType.resolved(@a)
    @a.add_field("foo", Opcodes.ACC_PUBLIC)
    @b.add_field("foo", Opcodes.ACC_PRIVATE)
    
    future = @lookup.findMethod(@scope, @b, 'foo', [], nil, nil, false)

    assert_equal("LA;", future.resolve.returnType.asm_type.descriptor)
  end

  def test_inaccessible
    @a.add_field("foo", Opcodes.ACC_PRIVATE)

    future = @lookup.findMethod(@scope, @b, 'foo', [], nil, nil, false)

    assert(future.resolve.isError, "Expected error, got #{future.resolve}")
  end

  def test_field_setter
    @a.add_field("foo")

    future = @lookup.findMethod(@scope, @a, 'foo_set', [@a], nil, nil, false)
  end
end