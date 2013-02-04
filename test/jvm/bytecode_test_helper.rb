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
require 'stringio'
require 'fileutils'

module JVMCompiler
  TEST_DEST = File.expand_path(File.dirname(__FILE__)+'/../../tmp/') + "/"
  $CLASSPATH << TEST_DEST

  import java.lang.System
  import java.io.PrintStream
  include Mirah

  def new_state
    state = Mirah::Util::CompilationState.new
    state.save_extensions = true
    state.destination = TEST_DEST
    state.classpath =  TEST_DEST
    state
  end

  def clean_tmp_directory
    FileUtils.rm_rf TEST_DEST
    FileUtils.mkdir_p TEST_DEST
  end

  def clean_tmp_files
    return unless @tmp_classes
    File.unlink(*@tmp_classes)
    @tmp_classes.clear
  end

  def compiler_type
    JVM::Compiler::JVMBytecode
  end

  def parse name, code, transformer
    AST.parse(code, name, true, transformer)
  end

 def infer_and_resolve_types ast, generator
   scoper, typer = generator.infer_asts(ast, true)
   ast
 end

 def parse_and_resolve_types name, code
   state = new_state

   generator = Mirah::Generator.new(state, compiler_type, false, false)
   transformer = Mirah::Transform::Transformer.new(state, generator.typer)

   ast = [AST.parse(code, name, true, transformer)]

   infer_and_resolve_types ast, generator

   ast
 end


  def generate_classes compiler_results
    classes = {}

    compiler_results.each do |result|
      bytes = result.bytes
      filename = "#{TEST_DEST}/#{result.filename}"
      FileUtils.mkdir_p(File.dirname(filename))
      File.open(filename, 'wb') { |f| f.write(bytes) }
      @tmp_classes << "#{filename}.class"
      classes[result.filename[0..-7]] = Mirah::Util::ClassLoader.binary_string bytes
    end

    loader = Mirah::Util::ClassLoader.new(JRuby.runtime.jruby_class_loader, classes)

    classes.keys.map do |name|
      cls = loader.load_class(name.tr('/', '.'))
      JavaUtilities.get_proxy_class(cls.name)
    end
  end

  def compile(code, name = tmp_script_name)
    state = new_state

    generator = Mirah::Generator.new(state, compiler_type, false, false)
    transformer = Mirah::Transform::Transformer.new(state, generator.typer)

    ast = AST.parse(code, name, true, transformer)

    scoper, typer = generator.infer_asts([ast], true)
    compiler_results = generator.compiler.compile_asts([ast], scoper, typer)

    generate_classes compiler_results
  end

  def tmp_script_name
    "script" + System.nano_time.to_s
  end
end


module CommonAssertions
  import java.lang.System
  import java.io.PrintStream

  def assert_include(value, array, message=nil)
    message = build_message message, '<?> does not include <?>', array, value
    assert_block message do
      array.include? value
    end
  end

  def capture_output
    saved_output = System.out
    output = StringIO.new
    System.setOut(PrintStream.new(output.to_outputstream))
    begin
      yield
      output.rewind
      output.read
    ensure
      System.setOut(saved_output)
    end
  end

  def assert_output(expected, &block)
    assert_equal(expected, capture_output(&block))
  end

end

class Test::Unit::TestCase
  include JVMCompiler

  class << self
    include JVMCompiler
    def startup
      clean_tmp_directory
    end
  end

  def setup
    @tmp_classes = []

  end

  def cleanup
    clean_tmp_files
  end
end
