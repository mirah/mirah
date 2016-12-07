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


require "test_helper"
require ENV.fetch('MIRAHC_JAR',File.expand_path("../../../dist/mirahc.jar",__FILE__))

class BaseMirrorsTest < Test::Unit::TestCase
  java_import 'org.mirah.jvm.mirrors.MirrorTypeSystem'
  java_import 'org.mirah.jvm.mirrors.BetterScopeFactory'
  java_import 'org.mirah.jvm.types.JVMType'
  java_import 'org.mirah.jvm.types.JVMTypeUtils'
  java_import 'org.mirah.typer.AssignableTypeFuture'
  java_import 'org.mirah.typer.BaseTypeFuture'
  java_import 'org.mirah.typer.CallFuture'
  java_import 'org.mirah.typer.TypeFuture'
  java_import 'org.mirah.typer.simple.SimpleScoper'
  java_import 'mirah.lang.ast.ClassDefinition'
  java_import 'mirah.lang.ast.ConstructorDefinition'
  java_import 'mirah.lang.ast.PositionImpl'
  java_import 'mirah.lang.ast.Script'
  java_import 'mirah.lang.ast.StringCodeSource'
  java_import 'mirah.lang.ast.TypeRefImpl'
  java_import 'org.objectweb.asm.Opcodes'
  java_import 'org.objectweb.asm.Type'

  def setup
    @types = MirrorTypeSystem.new
    @scope = new_scope
    set_filename('foo-bar.mirah')
  end

  def new_scope opts={}
    BetterScopeFactory.new.newScope(SimpleScoper.new(nil), opts[:context] || Script.new)
  end

  def set_filename(filename)
    @script = Script.new(PositionImpl.new(StringCodeSource.new(filename, ""),
                         0, 0, 0, 0, 0, 0))
  end

  def assert_descriptor(descriptor, type)
    assert(type.isResolved, type.resolve.toString)
    assert_not_error(type)
    assert_resolved_to(descriptor, type.resolve)
  end

  def assert_resolved_to(descriptor, resolved)
    assert_kind_of(JVMType, resolved)
    assert_equal(descriptor, resolved.getAsmType.descriptor)
  end

  def assert_error(type)
    assert_block("Expected #{type.resolve} to be an error") {
      type.resolve.isError
    }
  end

  def assert_not_error(type)
    assert(!type.resolve.isError, type.resolve.toString)
  end

  def assert_subtype_of(supertype, subtype)
    converted_supertype = convert_to_type(supertype)
    assert_block("Invalid supertype #{supertype}") {
      !converted_supertype.isError
    }
    assert_block("Expected #{supertype} > #{subtype}") {
      converted_supertype.assignableFrom(convert_to_type(subtype))
    }
  end

  def convert_to_type(x)
    if x.kind_of?(JVMType)
      x
    elsif x.respond_to?(:resolve)
      x.resolve
    elsif x.kind_of?(TypeRefImpl)
      @types.get(@scope, x).resolve
    else
      @types.get(@scope, typeref(x)).resolve
    end
  end

  def main_type
    @types.getMainType(@scope, @script)
  end

  def typeref(name, array=false)
    TypeRefImpl.new(name, array, false, nil)
  end

  def define_type(name, superclass=nil, interfaces=[])
    @types.defineType(
        @scope, ClassDefinition.new, name, superclass, interfaces)
  end
end

class MirrorsTest < BaseMirrorsTest

  def test_add_default_imports
    @types.addDefaultImports(@scope)
    type = @types.get(@scope, typeref("StackTraceElement"))
    assert_descriptor("Ljava/lang/StackTraceElement;", type)
  end

  def test_fixnum
    type = @types.getFixnumType(0)
    assert_descriptor("I", type)
    assert_descriptor("J", @types.getFixnumType(1 << 33))
  end

  def test_fixnum_narrowing
    type = @types.getFixnumType(0)
    assert_descriptor("I", type)
    type.narrow
    assert_descriptor("B", type)

    type = @types.getFixnumType(1 << 8)
    assert_descriptor("I", type)
    type.narrow
    assert_descriptor("S", type)
  end

  def test_string
    assert_descriptor("Ljava/lang/String;", @types.getStringType)
  end

  def test_void
    type = @types.getVoidType
    assert_descriptor("V", type)
  end

  def test_nil
    type = @types.getImplicitNilType
    assert_not_nil(type)
    assert(type.resolve.matchesAnything)
    assert_descriptor("V", type)
  end

  def test_null
    type = @types.getNullType.resolve
    assert_equal("null", type.name)
    assert_resolved_to("Ljava/lang/Object;", type)
  end

  def test_main_type
    assert_descriptor("LFooBarTopLevel;", main_type)
  end
  
  def test_main_type2
    set_filename("some_class.mirah")
    assert_descriptor("LSomeClassTopLevel;", main_type)
  end

  def test_main_type_is_meta
    assert(main_type.resolve.isMeta)
  end

  def test_main_type_with_package
    @scope.package_set("foo.bar")
    assert_descriptor("Lfoo/bar/FooBarTopLevel;", main_type)
  end

  def test_regex
    assert_descriptor("Ljava/util/regex/Pattern;", @types.getRegexType)
  end

  def test_hash
    assert_descriptor("Ljava/util/Map;", @types.getHashLiteralType(@types.getStringType, @types.getRegexType, nil))
  end

  def test_float
    assert_descriptor("D", @types.getFloatType(0))
  end

  def test_float_narrowing
    type = @types.getFloatType(0.0)
    assert_descriptor("D", type)
    type.narrow
    assert_descriptor("F", type)
  end

  def test_exception
    assert_descriptor("Ljava/lang/Exception;", @types.getDefaultExceptionType)
  end

  def test_throwable
    assert_descriptor("Ljava/lang/Throwable;", @types.getBaseExceptionType)
  end

  def test_boolean
    assert_descriptor("Z", @types.getBooleanType)
  end

  def test_list
    assert_descriptor("Ljava/util/List;", @types.getArrayLiteralType(@types.getStringType, nil))
  end

  def test_superclass
    assert_descriptor("Ljava/lang/Object;", @types.getSuperClass(main_type))
  end

  def test_method_def
    type = @types.getMethodDefType(main_type, 'foobar', [], nil, nil)
    assert_error(type.returnType)
    type = @types.getMethodDefType(
        main_type, 'foobar', [], @types.getVoidType, nil)
    assert_descriptor('V', type.returnType)
  end

  def test_meta_resolved
    type = @types.getStringType.resolve
    assert(!type.isMeta)
    assert(@types.getMetaType(type).isMeta)
  end

  def test_meta_future
    type = @types.getStringType
    assert(!type.resolve.isMeta)
    assert(@types.getMetaType(type).resolve.isMeta)
  end

  def test_local
    type1 = @types.getLocalType(@scope, "ARGV", nil)
    type2 = @types.getLocalType(@scope, "ARGV", nil)
    type2.assign(@types.getFixnumType(0), nil)
    assert_descriptor("I", type1)
    assert_descriptor("I", type2)
  end

  def test_multiple_locals
    type1 = @types.getLocalType(@scope, "a", nil)
    type2 = @types.getLocalType(@scope, "b", nil)
    assert_error(type1)
    assert_error(type2)
    type1.assign(@types.getFixnumType(0), nil)
    assert_descriptor("I", type1)
    assert_error(type2)
    type2.assign(@types.getStringType, nil)
    assert_descriptor("I", type1)
    assert_descriptor("Ljava/lang/String;", type2)
  end

  def test_multiple_scopes
    type1 = @types.getLocalType(@scope, "a", nil)
    type2 = @types.getLocalType(new_scope, "a", nil)
    assert_error(type1)
    assert_error(type2)
    type1.assign(@types.getFixnumType(0), nil)
    assert_descriptor("I", type1)
    assert_error(type2)
    type2.assign(@types.getStringType, nil)
    assert_descriptor("I", type1)
    assert_descriptor("Ljava/lang/String;", type2)
  end

  def test_define_type
    type = define_type("Subclass", main_type)
    assert_descriptor("LSubclass;", type)
    assert_descriptor("LFooBarTopLevel;", @types.getSuperClass(type))
  end

  def test_define_inner_class_type
    type = define_type("SubclassTopLevel$Inner", main_type)
    assert_descriptor("LSubclassTopLevel$Inner;", type)
    assert_descriptor("LFooBarTopLevel;", @types.getSuperClass(type))
  end

  def test_redefine_main_type
    existing = main_type.resolve.unmeta
    type = @types.defineType(@scope, ClassDefinition.new, "FooBarTopLevel", nil, [])
    assert_descriptor("LFooBarTopLevel;", type)
    assert_same(existing, type.resolve)
  end

  def test_default_constructor
    object = @types.getSuperClass(main_type).resolve
    constructor = object.getMethod('<init>', [])
    assert_not_nil(constructor)
    assert_equal('CONSTRUCTOR', constructor.kind.name)
    assert_not_equal(0, constructor.flags & Opcodes.ACC_PUBLIC)
  end

  def test_get
    type = @types.get(@scope, typeref('void'))
    assert_descriptor('V', type)
  end

  def test_package
    @scope.package_set('foo')
    type = define_type('Bar')
    assert_descriptor("Lfoo/Bar;", type)
    
    @scope.package_set('foo.bar')
    assert_descriptor("Lfoo/bar/Baz;", define_type('Baz'))
  end

  def test_search_packages
    define_type("A")
    define_type("B")
    @scope.package_set('foo')
    define_type("A")
    @scope.package_set('bar')
    define_type("A")
    
    @scope.import("bar", "*")
    @scope.package_set(nil)
    ref = typeref('A')
    assert_descriptor("LA;", @types.get(@scope, ref))

    @scope.package_set("foo")
    assert_descriptor("Lfoo/A;", @types.get(@scope, ref))

    @scope.package_set("baz")
    assert_descriptor("Lbar/A;", @types.get(@scope, ref))

    # This isn't quite right. Primitive types should be visible,
    # but other classes in the default package shouldn't be accessible
    # to other packages.
    assert_descriptor("LB;", @types.get(@scope, typeref('B')))
  end

  def test_import
    @scope.import('java.util.Map', 'JavaMap')
    assert_descriptor("Ljava/util/Map;", @types.get(@scope, typeref('JavaMap')))
  end

  def test_classname_from_filename
    assert_equal("SomeClassTopLevel",
                 MirrorTypeSystem.classnameFromFilename("SomeClass.mirah"))
    assert_equal("FooBarTopLevel",
                 MirrorTypeSystem.classnameFromFilename("FooBar.mirah"))
    assert_equal("SomeClassTopLevel",
                 MirrorTypeSystem.classnameFromFilename("some_class.mirah"))
    assert_equal("FooBarTopLevel",
                 MirrorTypeSystem.classnameFromFilename("foo-bar.mirah"))
    assert_equal(
        "SomeClassTopLevel",
        MirrorTypeSystem.classnameFromFilename("foo/bar/some_class.mirah"))
  end

  def test_primitive_array
    array_type = @types.get(@scope, typeref('int', true)).resolve
    assert_resolved_to('[I', array_type)
    assert(JVMTypeUtils.isArray(array_type))
    assert_subtype_of('java.lang.Object', array_type)
    assert_subtype_of('java.lang.Cloneable', array_type)
    assert_subtype_of('java.io.Serializable', array_type)
    assert_resolved_to('I', array_type.component_type)
    assert_descriptor(
        '[S', @types.getArrayType(@types.get(@scope, typeref('short'))))
  end


  # TODO write test checking
  # use of instance field from static method

  def test_field_before_declaration
    a = @types.getFieldType(main_type, 'a', nil)
    b = @types.getFieldType(main_type, 'b', nil)
    assert_not_same(a, b)
    assert_same(a, @types.getFieldType(main_type, 'a', nil))

    field = main_type.resolve.getDeclaredField('a')
    assert(field.nil?, "expected field to be undeclared yet")
  end

  def test_separate_fields_without_declare_return_separate_futures
    a = @types.getFieldType(main_type, 'a', nil)
    b = @types.getFieldType(main_type, 'b', nil)
    assert_not_same(a, b)
  end

  def test_separate_fields_with_declare_return_separate_futures
    a = @types.getFieldTypeOrDeclare(main_type, 'a', nil)
    b = @types.getFieldTypeOrDeclare(main_type, 'b', nil)
    assert_not_same(a, b)
  end

  def test_declared_field_is_same_as_get_field_when_declared_first
    a = @types.getFieldTypeOrDeclare(main_type, 'a', nil)
    assert_same(a, @types.getFieldType(main_type, 'a', nil))
  end

  def test_declared_field_is_same_as_get_field_when_declared_second
    a = @types.getFieldType(main_type, 'a', nil)
    assert_same(a, @types.getFieldTypeOrDeclare(main_type, 'a', nil))
  end

  def test_field_attrs_of_declared_field
    a = @types.getFieldTypeOrDeclare(main_type, 'a', nil)
    
    field = main_type.resolve.getDeclaredField('a')

    assert_same(a, field.async_return_type)
    assert_equal("STATIC_FIELD_ACCESS", field.kind.name)
    
    assert_same(field, main_type.resolve.unmeta.getDeclaredField('a'))
  end
end

class MTS_MethodLookupTest < BaseMirrorsTest
  def setup
    super
    @scope.selfType_set(main_type)
  end


  def test_simple_method_def
    @types.getMethodDefType(main_type, 'foobar', [], @types.getVoidType, nil)
    type = @types.getMethodType(
        CallFuture.new(@types, @scope, main_type, true, 'foobar', [], [], nil))
    assert_resolved_to('LFooBarTopLevel;', type.resolve.returnType)
  end

  def test_multiple_method_defs
    @types.getMethodDefType(main_type, 'foobar', [], @types.getVoidType, nil)
    @types.getMethodDefType(main_type, 'foo', [], @types.getFixnumType(1), nil)
    type = @types.getMethodType(
        CallFuture.new(@types, @scope, main_type, true, 'foobar', [], [], nil))
    assert_not_error(type)
    assert_resolved_to('LFooBarTopLevel;', type.resolve.returnType)
    type = @types.getMethodType(
        CallFuture.new(@types, @scope, main_type, true, 'foo', [], [], nil))
    assert_not_error(type)
    assert_resolved_to('I', type.resolve.returnType)
  end

  def test_method_def_nil
    @types.getMethodDefType(main_type, 'foobar', [], @types.getNullType, nil)
    type = @types.getMethodType(
        CallFuture.new(@types, @scope, main_type, true, 'foobar', [], [], nil))
    assert_not_equal('null', type.resolve.returnType.name)
    assert_resolved_to('Ljava/lang/Object;', type.resolve.returnType)
  end

  def test_async_return_type
    future = BaseTypeFuture.new
    @types.getMethodDefType(main_type, 'foo', [], future, nil)
    type = @types.getMethodType(
        CallFuture.new(@types, @scope, main_type, true, 'foo', [], [], nil))
    assert_error(type)
    future.resolved(@types.getFixnumType(1).resolve)
    assert_not_error(type)
    assert_resolved_to('I', type.resolve.returnType)
  end

  def test_async_return_type_from_superclass
    a = define_type('A')
    b = define_type('B', a)
    type = CallFuture.new(@types, @scope, b, true, 'foo', [], [], nil)
    assert_error(type)
    @types.getMethodDefType(a, 'foo', [], a, nil)
    assert_not_error(type)
    assert_descriptor('LA;', type)
  end

  def test_async_return_type_from_interface
    a = define_type('A')
    b = define_type('B', main_type, [a])
    type = CallFuture.new(@types, @scope, b, true, 'foo', [], [], nil)
    assert_error(type)
    @types.getMethodDefType(a, 'foo', [], a, nil)
    assert_not_error(type)
    assert_descriptor('LA;', type)
  end

  def test_infer_return_type_from_body
    future = @types.getMethodDefType(main_type, 'foo', [], nil, nil)
    type = @types.getMethodType(
        CallFuture.new(@types, @scope, main_type, true, 'foo', [], [], nil))
    assert_error(type)
    future.returnType.assign(@types.getFixnumType(1), nil)
    assert_not_error(type)
    assert_resolved_to('I', type.resolve.returnType)
  end

  def test_async_arguments
    type = @types.wrap(Type.getType("LFooBarTopLevel;"))
    @scope.selfType_set(type)
    int = @types.wrap(Type.getType("I"))
    short = @types.wrap(Type.getType("S"))
    decl = AssignableTypeFuture.new(nil)
    decl.declare(int, nil)
    @types.getMethodDefType(type, 'foo', [decl], int, nil)
    argument_future = BaseTypeFuture.new
    decl = AssignableTypeFuture.new(nil)
    decl.declare(argument_future, nil)
    @types.getMethodDefType(type, 'foo', [decl], short, nil)

    call_future = CallFuture.new(@types, @scope, type, true, 'foo', [short], [], nil)
    assert_not_error(call_future)
    assert_resolved_to('I', call_future.resolve)

    # Now make the other one more specific
    argument_future.resolved(short.resolve)
    assert_resolved_to('S', call_future.resolve)
  end

  def test_async_arguments_meta
    int = @types.wrap(Type.getType("I"))
    short = @types.wrap(Type.getType("S"))
    decl = AssignableTypeFuture.new(nil)
    decl.declare(int, nil)
    @types.getMethodDefType(main_type, 'foo', [decl], int, nil)
    argument_future = BaseTypeFuture.new
    decl = AssignableTypeFuture.new(nil)
    decl.declare(argument_future, nil)
    @types.getMethodDefType(main_type, 'foo', [decl], short, nil)

    call_future = CallFuture.new(@types, @scope, main_type, true, 'foo', [short], [], nil)
    assert_not_error(call_future)
    assert_resolved_to('I', call_future.resolve)

    # Now make the other one more specific
    argument_future.resolved(short.resolve)
    assert_resolved_to('S', call_future.resolve)
  end

  def test_main_type_not_error
    assert_not_error(main_type)
  end

  def test_when_superclass_unresolved_then_call_futures_in_error
    super_future = BaseTypeFuture.new
    subclass   = @types.defineType(@scope, ClassDefinition.new, "Subclass", super_future, [])
    superclass = @types.defineType(@scope, ClassDefinition.new, "UltimateSuperClass", nil, [])
    decl = AssignableTypeFuture.new(nil)
    decl.declare(superclass, nil)
    
    @types.getMethodDefType(main_type, 'foobar', [decl],
                            @types.getFixnumType(0), nil)
    type = CallFuture.new(@types, @scope, main_type, true, 'foobar', [subclass], [], nil)
    assert_error(type)
  end

  def test_when_superclass_of_superclass_unresolved_then_call_future_in_error
    super_future = BaseTypeFuture.new
    subclass     = @types.defineType(@scope, ClassDefinition.new, "Subclass", super_future, [])
    sub_subclass = @types.defineType(@scope, ClassDefinition.new, "SubSubclass", super_future, [])
    superclass   = @types.defineType(@scope, ClassDefinition.new, "UltimateSuperClass", nil, [])
    decl = AssignableTypeFuture.new(nil)
    decl.declare(superclass, nil)

    @types.getMethodDefType(main_type, 'foobar', [decl],
                            @types.getFixnumType(0), nil)
    type = CallFuture.new(@types, @scope, main_type, true, 'foobar', [sub_subclass], [], nil)
    assert_error(type)
  end

  def test_after_unresolved_superclass_resolves_then_call_future_not_error
    super_future = BaseTypeFuture.new
    subclass   = @types.defineType(@scope, ClassDefinition.new, "Subclass", super_future, [])
    superclass = @types.defineType(@scope, ClassDefinition.new, "UltimateSuperClass", nil, [])
    decl = AssignableTypeFuture.new(nil)
    decl.declare(superclass, nil)

    @types.getMethodDefType(main_type, 'foobar', [decl],
                            @types.getFixnumType(0), nil)

    type = CallFuture.new(@types, @scope, main_type, true, 'foobar', [subclass], [], nil)

    super_future.resolved(superclass.resolve)

    assert_descriptor("I", type)
  end

  def test_after_unresolved_superclass_of_superclass_resolves_then_call_future_not_error
    super_future = BaseTypeFuture.new
    subclass     = @types.defineType(@scope, ClassDefinition.new, "Subclass", super_future, [])
    sub_subclass = @types.defineType(@scope, ClassDefinition.new, "SubSubclass", super_future, [])
    superclass   = @types.defineType(@scope, ClassDefinition.new, "UltimateSuperClass", nil, [])
    decl = AssignableTypeFuture.new(nil)
    decl.declare(superclass, nil)
    @types.getMethodDefType(main_type, 'foobar', [decl],
                            @types.getFixnumType(0), nil)
    type = CallFuture.new(@types, @scope, main_type, true, 'foobar', [sub_subclass], [], nil)

    super_future.resolved(superclass.resolve)

    assert_descriptor("I", type)
  end

  def test_nulltype_methods
    type = CallFuture.new(@types, @scope, @types.getNullType, true, 'nil?', [], [], nil)
    assert_not_error(type)
    assert_descriptor('Z', type)
  end

  def test_super_in_constructor
    @scope = new_scope context: ConstructorDefinition.new
    @scope.selfType_set(main_type)

    future = CallFuture.new(
        @types, @scope,
        @types.getSuperClass(main_type), true, 'initialize', [], [], nil)
    assert_descriptor("Ljava/lang/Object;", future)
  end

  def test_array_methods
    index_type = @types.get(@scope, typeref('int'))
    component_type = @types.get(@scope, typeref('short'))
    array_type = @types.get(@scope, typeref('short', true))
    
    method = @types.getMethodType(CallFuture.new(
        @types, @scope, array_type, true, 'length', [], [], nil))
    assert_resolved_to('I', method.resolve.returnType)
    method = @types.getMethodType(CallFuture.new(
        @types, @scope, array_type, true, '[]', [index_type], [], nil))
    assert_resolved_to('S', method.resolve.returnType)
    method = @types.getMethodType(CallFuture.new(
        @types, @scope, array_type, true,
        '[]=', [index_type, component_type], [], nil))
    assert_resolved_to('S', method.resolve.returnType)
  end

  def test_field_access_via_call
    system = @types.get(@scope, typeref('java.lang.System'))
    method = @types.getMethodType(CallFuture.new(
        @types, @scope, system, true, 'out', [], [], nil))
    assert_not_error(method)
    assert_resolved_to("Ljava/io/PrintStream;", method.resolve.returnType)
    member = method.resolve.returnType.member
    assert_equal('STATIC_FIELD_ACCESS', member.kind.name)
  end

  def test_constructor
    object = @types.get(@scope, typeref('java.lang.Object'))
    object_meta = @types.getMetaType(object)
    method = CallFuture.new(
        @types, @scope, object_meta, true, 'new', [], [], nil)
    assert_descriptor('Ljava/lang/Object;', method)
  end

  def test_implicit_nil_widen
    a = @types.getStringType.resolve
    b = @types.getImplicitNilType.resolve
    c = a.widen(b)
    assert_resolved_to('Ljava/lang/String;', c)
  end

  def test_object_widen
    a = @types.getStringType.resolve
    b = @types.getRegexType.resolve
    c = a.widen(b)
    assert_resolved_to('Ljava/io/Serializable;', c)
  end

  def test_boxed_assignment
    a = @types.wrap(Type.getType("Ljava/lang/Boolean;")).resolve
    b = @types.getBooleanType.resolve
    assert(a.assignableFrom(b))
    assert(b.assignableFrom(a))
  end

  def test_same_type
    a = @types.getStringType.resolve
    assert(a.isSameType(a))
  end

  def test_class_literal
    object = @types.get(@scope, typeref('java.lang.Object'))
    object_meta = @types.getMetaType(object)
    method = CallFuture.new(
        @types, @scope, object_meta, true, 'class', [], [], nil)
    assert_equal('java.lang.Class<java.lang.Object>', method.resolve.toString)

    method = CallFuture.new(
        @types, @scope, main_type, true, 'class', [], [], nil)
    assert_equal('java.lang.Class<FooBarTopLevel>', method.resolve.toString)
  end

  def test_generic_method
    klass = CallFuture.new(
        @types, @scope, main_type, true, 'class', [], [], nil)
    collections = @types.getMetaType(
        @types.get(@scope, typeref('java.util.Collections')))
    set = @types.get(@scope, typeref('java.util.Set'))
    checked = CallFuture.new(
        @types, @scope, collections, true, 'checkedSet', [set, klass], [], nil)
    assert_equal('java.util.Set<FooBarTopLevel>', checked.resolve.toString)
  end

  def test_wildcard_return
    loader = @types.get(@scope, typeref('java.lang.ClassLoader'))
    klass = CallFuture.new(
        @types, @scope, loader, true, 'loadClass',
        [@types.getStringType], [], nil)
    assert(klass.resolve.assignableFrom(klass.resolve), klass.resolve.toString)
  end

  def test_nil_argument
    sb = @types.get(@scope, typeref('java.lang.StringBuilder'))
    result = CallFuture.new(@types, @scope, sb, true, 'append', [@types.getNullType], [], nil)
    assert_descriptor('Ljava/lang/StringBuilder;', result)
  end
end