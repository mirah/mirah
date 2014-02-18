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

module JVMCompiler
  java_import 'org.mirah.tool.RunCommand'
  java_import 'org.mirah.util.SimpleDiagnostics'
  class TestDiagnostics < SimpleDiagnostics
    java_import 'java.util.Locale'
    def report(diagnostic)
      if diagnostic.kind.name == "ERROR"
        raise Mirah::MirahError, diagnostic.getMessage(Locale.getDefault)
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
    name = options.delete :name
    name ||= tmp_script_name

    java_version = options.delete :java_version
    args = ["-d", TEST_DEST,
            "--vmodule", "org.mirah.jvm.compiler.ClassCompiler=OFF",
            "--classpath", Mirah::Env.encode_paths([FIXTURE_TEST_DEST, TEST_DEST]) ]
    if java_version
      args += ["--jvm", java_version]
    end

    cmd = build_command name, code
    compile_or_raise cmd, args

    dump_class_files cmd.classMap

    cmd.loadClasses.map {|cls| JRuby.runtime.java_support.getProxyClassFromCache(cls)}
  end

  def build_command(name, code)
    cmd = RunCommand.new
    cmd.addFakeFile(name, code)
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
    File.unlink(*@tmp_classes)
  end

  def setup
    @tmp_classes = Set.new
  end

  def cleanup
    clean_tmp_files
  end

  def dump_class_files class_map
    class_map.each do |filename, bytes|
      filename = "#{TEST_DEST}#{filename}.class"
      FileUtils.mkdir_p(File.dirname(filename))
      File.open(filename, 'wb') { |f| f.write(bytes) }
      @tmp_classes << filename
    end
  end
end
