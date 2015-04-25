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

class BytecodeMirrorTest < Test::Unit::TestCase
  java_import 'org.objectweb.asm.Type'
  java_import 'org.mirah.jvm.mirrors.MirrorTypeSystem'
  java_import 'org.mirah.jvm.mirrors.ClassLoaderResourceLoader'
  java_import 'org.mirah.jvm.mirrors.ClassResourceLoader'
  java_import 'org.mirah.jvm.types.JVMTypeUtils'
  java_import 'org.mirah.IsolatedResourceLoader'

  def setup
    class_based_loader = ClassResourceLoader.new(MirrorTypeSystem.java_class)
    loader = ClassLoaderResourceLoader.new(
                IsolatedResourceLoader.new([TEST_DEST,FIXTURE_TEST_DEST].map{|u|java.net.URL.new "file:"+u}),
                class_based_loader)
    @types = MirrorTypeSystem.new nil, loader
  end

  def load(desc)
    @types.wrap(desc).resolve
  end

  def test_parent
    mirror = load(Type.getType("I"))
    assert_equal("I", mirror.asm_type.descriptor)
  end

  def test_classloading
    mirror = load(Type.getType("Ljava/lang/Object;"))
    assert(!mirror.isError)
    assert_equal("java.lang.Object", mirror.name)
  end

  def test_inner_class
    mirror = load(Type.getType("Ljava/util/Map/Entry;"))
    assert(!mirror.isError)
    assert_equal("java.util.Map$Entry", mirror.name)
  end

  def test_superclass
    mirror = load(Type.getType("Ljava/lang/String;"))
    assert(!mirror.isError)
    assert_equal("java.lang.String", mirror.name)
    
    superclass = mirror.superclass
    assert(!superclass.isError)
    assert_equal("java.lang.Object", superclass.name)
    assert_nil(superclass.superclass)
  end

  def test_interfaces
    mirror = load(Type.getType("Ljava/lang/String;"))
    interfaces = mirror.interfaces.map {|t| t.resolve.name}
    assert_equal(['java.io.Serializable', 'java.lang.Comparable', 'java.lang.CharSequence'], interfaces)
  end

  def test_declared_field
    mirror = load(Type.getType("Ljava/lang/String;"))
    field = mirror.getDeclaredField('hash')
    assert_equal(mirror, field.declaringClass)
    assert_equal('hash', field.name)
    assert_equal([], field.argumentTypes.to_a)
    assert_equal('I', field.returnType.asm_type.descriptor)
    assert(!field.isVararg)
    assert(!field.isAbstract)
    assert_equal('FIELD_ACCESS', field.kind.name)
  end

  def test_declared_field_signature
    mirror = load(Type.getType("Ljava/lang/String;"))
    field = mirror.getDeclaredField 'CASE_INSENSITIVE_ORDER'

    assert_equal('Ljava/util/Comparator<Ljava/lang/String;>;', field.signature)
  end

  def test_array
    mirror = load(Type.getType("[Ljava/lang/Object;"))
    assert(JVMTypeUtils.isArray(mirror))
    assert_equal("Ljava/lang/Object;", mirror.getComponentType.asm_type.descriptor)
  end

  def test_annotation_retention_with_runtime
    mirror = load(Type.getType("Ljava/lang/annotation/Retention;"))
    assert_equal("RUNTIME", mirror.retention)
  end

  def test_annotation_retention_with_source
    mirror = load(Type.getType("Ljava/lang/Override;"))
    assert_equal("SOURCE", mirror.retention)
  end

  def test_annotation_retention_with_class
    mirror = load(Type.getType("Lorg/foo/ImplicitClassRetAnno;"))
    assert_equal("CLASS", mirror.retention)
  end
end