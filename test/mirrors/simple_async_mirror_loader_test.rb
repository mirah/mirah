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
require 'java'
require ENV.fetch('MIRAHC_JAR',File.expand_path("../../../dist/mirahc.jar",__FILE__))

class SimpleAsyncMirrorLoaderTest < Test::Unit::TestCase
  java_import 'org.objectweb.asm.Type'
  java_import 'org.mirah.jvm.mirrors.BaseType'
  java_import 'org.mirah.jvm.mirrors.MirrorType'
  java_import 'org.mirah.jvm.mirrors.SimpleAsyncMirrorLoader'
  java_import 'org.mirah.jvm.mirrors.AsyncLoaderAdapter'
  java_import 'org.mirah.jvm.mirrors.PrimitiveLoader'
  java_import 'org.mirah.jvm.types.JVMTypeUtils'
  java_import 'org.mirah.typer.BaseTypeFuture'
  java_import 'org.mirah.typer.ErrorType'
  java_import 'org.mirah.util.Context'

  def test_no_parent
    loader = SimpleAsyncMirrorLoader.new(nil)
    future = loader.loadMirrorAsync(Type.getType("V"))
    mirror = future.resolve
    assert(mirror.isError)
    assert_kind_of(MirrorType, mirror)
    assert_kind_of(ErrorType, mirror)
  end

  def test_define_type
    loader = SimpleAsyncMirrorLoader.new(nil)
    expected_future = BaseTypeFuture.new
    loader.defineMirror(Type.getType("V"), expected_future)
    actual_future =  loader.loadMirrorAsync(Type.getType("V"))
    expected_future.resolved(BaseType.new(nil, Type.getType("V"), 0, nil))
    assert_equal("void", expected_future.resolve.name)
  end


  def test_define_type_later
    loader = SimpleAsyncMirrorLoader.new(nil)
    actual_future =  loader.loadMirrorAsync(Type.getType("V"))
    assert(actual_future.resolve.isError)
    expected_future = BaseTypeFuture.new
    expected_future.resolved(BaseType.new(nil, Type.getType("V"), 0, nil))
    loader.defineMirror(Type.getType("V"), expected_future)
    assert_equal("void", expected_future.resolve.name)
  end

  def defineType(loader, type, mirror)
    future = BaseTypeFuture.new
    future.resolved(mirror)
    loader.defineMirror(type, future)
  end

  def test_parent
    parent = SimpleAsyncMirrorLoader.new(nil)
    child = SimpleAsyncMirrorLoader.new(nil, parent)
    
    defineType(parent, Type.getType("LA;"),
               BaseType.new(nil, Type.getType("Lparent/A;"), 0, nil))
    defineType(child, Type.getType("LA;"),
               BaseType.new(nil, Type.getType("Lchild/A;"), 0, nil))
    
    future = child.loadMirrorAsync(Type.getType("LA;"))
    assert_equal("child.A", future.resolve.name)
    
    future = child.loadMirrorAsync(Type.getType("LB;"))
    assert(future.resolve.isError)
    
    defineType(parent, Type.getType("LB;"),
               BaseType.new(nil, Type.getType("Lparent/B;"), 0, nil))
    assert_equal("parent.B", future.resolve.name)
    defineType(child, Type.getType("LB;"),
               BaseType.new(nil, Type.getType("Lchild/B;"), 0, nil))
    assert_equal("child.B", future.resolve.name)
  end

  def test_adapter
    loader = AsyncLoaderAdapter.new(nil, PrimitiveLoader.new(nil))
    future = loader.loadMirrorAsync(Type.getType("I"))
    assert_equal('int', future.resolve.name)
  end

  def test_array
    pend "undefined ClassPath class" do
    
    context = Context.new
    classpath = ClassPath.new
    classpath.bytecode_loader_set PrimitiveLoader.new(context)
    classpath.macro_loader_set classpath.bytecode_loader
    classpath.loader_set(loader = SimpleAsyncMirrorLoader.new(context))
    context.add(ClassPath.java_class, classpath)
    future = classpath.loader.loadMirrorAsync(Type.getType("[LA;"))
    defineType(loader, Type.getType("LA;"),
               BaseType.new(nil, Type.getType("LA;"), 0, nil))
    assert(JVMTypeUtils.isArray(future.resolve))
    assert_equal('LA;', future.resolve.getComponentType.asm_type.descriptor)
    assert(!future.resolve.getComponentType.isError)

    end
  end
end