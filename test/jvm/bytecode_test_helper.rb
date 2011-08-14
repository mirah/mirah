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
require 'jruby'
require 'stringio'
require 'fileutils'


module JVMCompiler
  import java.lang.System
  import java.io.PrintStream
  include Mirah
  
  def compile(code)
    File.unlink(*@tmp_classes)
    @tmp_classes.clear
    AST.type_factory = Mirah::JVM::Types::TypeFactory.new
    name = "script" + System.nano_time.to_s
    state = Mirah::Util::CompilationState.new
    state.save_extensions = false
    transformer = Mirah::Transform::Transformer.new(state)
    Java::MirahImpl::Builtin.initialize_builtins(transformer)
    ast  = AST.parse(code, name, true, transformer)
    typer = JVM::Typer.new(transformer)
    ast.infer(typer, true)
    typer.resolve(true)
    compiler = JVM::Compiler::JVMBytecode.new
    compiler.compile(ast)
    classes = {}
    loader = Mirah::Util::ClassLoader.new(JRuby.runtime.jruby_class_loader, classes)
    compiler.generate do |name, builder|
      bytes = builder.generate
      FileUtils.mkdir_p(File.dirname(name))
      open("#{name}", "wb") do |f|
        f << bytes
      end
      classes[name[0..-7]] = bytes
    end

    classes.keys.map do |name|
      cls = loader.load_class(name.tr('/', '.'))
      proxy = JavaUtilities.get_proxy_class(cls.name)
      @tmp_classes << "#{name}.class"
      proxy
    end
  end
end


module CommonAssertions
  def assert_include(value, array, message=nil)
    message = build_message message, '<?> does not include <?>', array, value
    assert_block message do
      array.include? value
    end
  end
end

class Test::Unit::TestCase
  include JVMCompiler
  include CommonAssertions
  
  def setup
    @tmp_classes = []
  end

  def teardown
    AST.type_factory = nil
    File.unlink(*@tmp_classes)
  end
end