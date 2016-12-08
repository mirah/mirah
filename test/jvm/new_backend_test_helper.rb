# Copyright (c) 2010-2013 The Mirah project authors. All Rights Reserved.
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

module JVMCompiler
  java_import 'org.mirah.tool.RunCommand'
  java_import 'org.mirah.util.SimpleDiagnostics'
  
  System = java.lang.System
  JVM_VERSION = ENV['MIRAH_TEST_JVM_VERSION'] || '1.7'

  class TestDiagnostics < SimpleDiagnostics
    java_import 'java.util.Locale'
    def report(diagnostic)
      if diagnostic.kind.name == "ERROR"
        source =  if diagnostic.source

                    line_no = [0, diagnostic.getLineNumber - diagnostic.source.initial_line].max
                    line = diagnostic.source.contents.lines.to_a[line_no]
                    start_col = if line_no == 0
                                  diagnostic.column_number - diagnostic.source.initial_column
                                else
                                  diagnostic.column_number - 1
                                end
                    end_col = [start_col + (diagnostic.end_position - diagnostic.start_position),
                               line.size - 1].min
                    line[start_col..end_col]
                  else
                    "<unknown>"
                  end
        raise Mirah::MirahError.new(diagnostic.getMessage(Locale.getDefault), source, diagnostic)
      end
      super
    end
  end
  def parse_and_resolve_types name, code
    cmd = build_command name, code
    compile_or_raise cmd, ["-d", TEST_DEST]
    cmd.compiler.getParsedNodes[0]
  end

  def compile(code, options = {})
    name = options.fetch :name, tmp_script_name

    args = ["-d", TEST_DEST,
            "--vmodule", "org.mirah.jvm.compiler.ClassCompiler=OFF",
            "--classpath", Mirah::Env.encode_paths([FIXTURE_TEST_DEST, TEST_DEST]) ]

    java_version = options.fetch :java_version, JVMCompiler::JVM_VERSION
    if java_version
      args += ["--jvm", java_version]
    end
    if options[:verbose]
      args << '--verbose'
    end
    if options[:separate_macro_dest]
      macro_dest = TEST_DEST.sub('classes','macro_classes')
      args += ["--macro-dest", macro_dest,
               "--macroclasspath", Mirah::Env.encode_paths([macro_dest])]
    end

    cmd = build_command name, code
    compile_or_raise cmd, args

    dump_class_files cmd.classMap

    cmd.loadClasses.map {|cls| JRuby.runtime.java_support.getProxyClassFromCache(cls)}
  end

  def build_command(name, code)
    cmd = RunCommand.new
    if code.is_a?(Array)
      code.each.with_index do |c,i|
        cmd.addFakeFile("#{name}_#{i}", c)
      end
    else
      cmd.addFakeFile(name, code)
    end
    cmd.setDiagnostics(TestDiagnostics.new(false))
    cmd
  end

  def compile_or_raise cmd, args
    if 0 != cmd.compile(args)
      raise Mirah::MirahError, "Compilation failed"
    end
  end

  def compiler_name
    "new"
  end

  def clean_tmp_files
    return unless @tmp_classes
    begin
      File.unlink(*@tmp_classes)
    rescue 
      JavaFile.unlink *@tmp_classes      
    end
  end

  def dump_class_files class_map
    class_map.each do |filename, bytes|
      filename = "#{TEST_DEST}#{filename}.class"
      FileUtils.mkdir_p(File.dirname(filename))
      File.open(filename, 'wb') { |f| f.write(bytes) }
      @tmp_classes << filename
    end
  end

  def tmp_script_name
    "#{name.gsub(/\)|\(/,'_').capitalize}#{System.nano_time.to_s[10..15]}"
  end

  def assert_raise_java(type, message=nil)
    begin
      yield
    rescue Exception => e
      ex = e
    end
    ex = ex.cause if ex.is_a? NativeException
    assert_equal type, ex.class
    if message
      if message.kind_of?(Regexp)
        assert_match message,
                     ex.message.to_s,
                    "expected error message to match #{message} but was '#{ex.message}'"
      else
        assert_equal message,
                     ex.message.to_s,
                    "expected error message to be '#{message}' but was '#{ex.message}'"
      end
    end
    ex
  end
  
  class JavaFile
    java_import 'java.io.File'
    
    def self.unlink *files            
      files.each do |f| 
        jf = File.new(f)
        unless jf.delete 
          jf.deleteOnExit
          puts "\nwarn: locked #{jf}"
        end
      end            
    end
  end
end

class Test::Unit::TestCase
  include JVMCompiler

  def setup
    @tmp_classes = Set.new
  end

  def cleanup
    clean_tmp_files
  end
end
