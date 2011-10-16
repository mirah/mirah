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

unless Mirah::AST.macro "__gloop__"
  Mirah::AST.defmacro "__gloop__" do |transformer, fcall, parent|
    Mirah::AST::Loop.new(parent, parent.position, true, false) do |loop|
      init, condition, check_first, pre, post = fcall.parameters
      loop.check_first = check_first.literal

      nil_t = Mirah::AST::Null
      loop.init = init
      loop.pre = pre
      loop.post = post

      body = fcall.block.body
      body.parent = loop
      [
        Mirah::AST::Condition.new(loop, parent.position) do |c|
          condition.parent = c
          [condition]
        end,
        body
      ]
    end
  end
end



module JVMCompiler
  import java.lang.System
  import java.io.PrintStream
  include Mirah
  
  def create_transformer
    state = Mirah::Util::CompilationState.new
    state.save_extensions = false
    
    transformer = Mirah::Transform::Transformer.new(state)
    Java::MirahImpl::Builtin.initialize_builtins(transformer)
    transformer
  end
  
  def reset_type_factory
    AST.type_factory = Mirah::JVM::Types::TypeFactory.new
  end
  
  def clear_tmp_files
    File.unlink(*@tmp_classes)
    @tmp_classes.clear
  end
  
  def create_compiler
    JVM::Compiler::JVMBytecode.new
  end
  
  def parse name, code, transformer
    AST.parse(code, name, true, transformer)
  end
  
  def infer_and_resolve_types ast, transformer
    typer = JVM::Typer.new(transformer)
    
    ast.infer(typer, true)
    
    typer.resolve(true)
  end
  
  def parse_and_resolve_types name, code    
    transformer = create_transformer
    
    ast  = parse name, code, transformer
    
    infer_and_resolve_types ast, transformer
    
    ast
  end
    
  
  def generate_classes compiler
    classes = {}

    compiler.generate do |filename, builder|
      bytes = builder.generate
      FileUtils.mkdir_p(File.dirname(filename))
      open("#{filename}", "wb") do |f|
        f << bytes
      end
      classes[filename[0..-7]] = Mirah::Util::ClassLoader.binary_string bytes
    end

    loader = Mirah::Util::ClassLoader.new(JRuby.runtime.jruby_class_loader, classes)
    classes.keys.map do |name|
      cls = loader.load_class(name.tr('/', '.'))
      proxy = JavaUtilities.get_proxy_class(cls.name)
      @tmp_classes << "#{name}.class"
      proxy
    end

  end
  
  def compile_ast  ast
    compiler = create_compiler
    compiler.compile(ast)
    compiler
  end
  
  def compile(code, name = tmp_script_name)
    clear_tmp_files
    reset_type_factory
    
    ast = parse_and_resolve_types name, code
    
    compiler = compile_ast ast
    
    generate_classes compiler
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
  include CommonAssertions
  
  def setup
    @tmp_classes = []
  end

  def teardown
    reset_type_factory
    clear_tmp_files
  end
end