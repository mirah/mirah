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

$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'mirah'
require 'mirah/jvm/source_compiler'
require 'jruby'
require 'stringio'
require File.join(File.dirname(__FILE__), 'test_jvm_compiler')

# make sure . is in CLASSPATH
$CLASSPATH << '.'

class TestJavacCompiler < TestJVMCompiler
  import javax.tools.ToolProvider
  import java.util.Arrays

  def teardown
    super
    # wipe out Script*_xform_* classes, since we're messy
    File.unlink(*Dir['Script*_xform_*.class'])
  end
  
  def javac(files)
    compiler = ToolProvider.system_java_compiler
    fm = compiler.get_standard_file_manager(nil, nil, nil)
    units = fm.get_java_file_objects_from_strings(Arrays.as_list(files.to_java :string))
    unless compiler.get_task(nil, fm, nil, nil, nil, units).call
      raise "Compilation error"
    end
    loader = org.jruby.util.ClassCache::OneShotClassLoader.new(
        JRuby.runtime.jruby_class_loader)
    classes = []
    files.each do |name|
      classfile = name.sub /java$/, 'class'
      if File.exist? classfile
        bytecode = IO.read(classfile)
        cls = loader.define_class(name[0..-6].tr('/', '.'), bytecode.to_java_bytes)
        classes << JavaUtilities.get_proxy_class(cls.name)
        @tmp_classes << name
        @tmp_classes << classfile 
      end
    end
    classes
  end
  
  def compile(code)
    File.unlink(*@tmp_classes)
    @tmp_classes.clear
    AST.type_factory = Mirah::JVM::Types::TypeFactory.new
    state = Mirah::Util::CompilationState.new
    state.save_extensions = false
    transformer = Mirah::Transform::Transformer.new(state)
    Java::MirahImpl::Builtin.initialize_builtins(transformer)
    name = "script" + System.nano_time.to_s
    ast  = AST.parse(code, name, true, transformer)
    typer = Typer::JVM.new(transformer)
    ast.infer(typer, true)
    typer.resolve(true)
    compiler = Compiler::JavaSource.new
    ast.compile(compiler, false)
    java_files = []
    compiler.generate do |name, builder|
      bytes = builder.generate
      FileUtils.mkdir_p(File.dirname(name))
      open("#{name}", "w") do |f|
        f << bytes
      end
      java_files << name
    end
    classes = javac(java_files)
  end
end