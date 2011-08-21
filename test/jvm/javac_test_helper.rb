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

require 'bundler/setup'
require 'test/unit'
require 'mirah'

require 'bytecode_test_helper'


require 'mirah/jvm/compiler/java_source'


# make sure . is in CLASSPATH
$CLASSPATH << '.'


module JavacCompiler
  import javax.tools.ToolProvider
  import java.util.Arrays
  import java.lang.System
  import java.io.PrintStream
  include Mirah
  
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
        pattern = classfile.sub /\.class$/, '$*.class'
        @tmp_classes.concat(Dir.glob(pattern))
      end
    end
    classes
  end
  
  def create_compiler
    JVM::Compiler::JavaSource.new
  end
  
  def compile_ast ast
    compiler = create_compiler
    ast.compile(compiler, false)
    compiler
  end
  
  def generate_classes compiler
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

  def clear_tmp_files
    super
    # wipe out Script*_xform_* classes, since we're messy
    File.unlink(*Dir['Script*_xform_*.class'])
  end
end


class Test::Unit::TestCase
  include JavacCompiler
  
end