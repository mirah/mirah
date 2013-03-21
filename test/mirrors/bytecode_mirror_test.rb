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

class BytecodeMirrorTest < Test::Unit::TestCase
  java_import 'org.jruby.org.objectweb.asm.Type'
  java_import 'org.mirah.jvm.mirrors.BytecodeMirrorLoader'
  java_import 'org.mirah.jvm.mirrors.PrimitiveLoader'

  def setup
    classloader = BytecodeMirrorLoader.java_class.class_loader
    @loader = BytecodeMirrorLoader.new(classloader, PrimitiveLoader.new)
  end
  
  def test_parent
    mirror = @loader.loadMirror(Type.getType("I"))
    assert_equal("I", mirror.class_id)
  end

  def test_classloading
    mirror = @loader.loadMirror(Type.getType("Ljava/lang/Object;"))
    assert(!mirror.isError)
    assert_equal("java.lang.Object", mirror.name)
  end

  def test_superclass
    mirror = @loader.loadMirror(Type.getType("Ljava/lang/String;"))
    assert(!mirror.isError)
    assert_equal("java.lang.String", mirror.name)
    
    superclass = mirror.superclass
    assert(!superclass.isError)
    assert_equal("java.lang.Object", superclass.name)
    assert_nil(superclass.superclass)
  end

  def test_interfaces
    mirror = @loader.loadMirror(Type.getType("Ljava/lang/String;"))
    interfaces = mirror.interfaces.map {|t| t.resolve.name}
    assert_equal(['java.io.Serializable', 'java.lang.Comparable', 'java.lang.CharSequence'], interfaces)
  end

  def test_declared_field
    mirror = @loader.loadMirror(Type.getType("Ljava/lang/String;"))
    field = mirror.getDeclaredField('hash')
    assert_equal(mirror, field.declaringClass)
    assert_equal('hash', field.name)
    assert_equal([], field.argumentTypes.to_a)
    assert_equal('I', field.returnType.class_id)
    assert(!field.isVararg)
    assert(!field.isAbstract)
    assert_equal('FIELD_ACCESS', field.kind.name)
  end

  def test_array
    mirror = @loader.loadMirror(Type.getType("[Ljava/lang/Object;"))
    assert(mirror.isArray)
    assert_equal("Ljava/lang/Object;", mirror.getComponentType.class_id)
  end
end