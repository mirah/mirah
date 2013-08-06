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

require 'rake'
require 'rake/testtask'
require 'rubygems'
require 'rubygems/package_task'
require 'bundler/setup'
require 'java'
require 'jruby/compiler'
require 'ant'

Gem::PackageTask.new Gem::Specification.load('mirah.gemspec') do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

bitescript_lib_dir = File.dirname Gem.find_files('bitescript').first

task :gem => ['jar:bootstrap', "javalib/mirah-compiler.jar", "javalib/mirah-mirrors.jar"]
task :bootstrap => ['javalib/mirah-bootstrap.jar', 'javalib/mirah-builtins.jar', 'javalib/mirah-util.jar']


task :default => :bytecode_ci

desc "run bytecode backend ci"
task :bytecode_ci => [:'test:core', :'test:jvm:bytecode']
desc "run new backend ci"
task :new_ci => [:'test:core', :'test:jvm:new']

def run_tests tests
  results = tests.map do |name|
    begin
      Rake.application[name].invoke
    rescue Exception
    end
  end

  tests.zip(results).each do |name, passed|
    unless passed
      puts "Errors in #{name}"
    end
  end
  fail if results.any?{|passed|!passed}
end

desc "run full test suite"
task :test do
  run_tests [ 'test:core', 'test:plugins', 'test:jvm', 'test:jvm:new' ]
end

namespace :test do

  desc "run the core tests"
  Rake::TestTask.new :core  => :bootstrap do |t|
    t.libs << 'test'
    t.test_files = FileList["test/core/**/*test.rb"]
    java.lang.System.set_property("jruby.duby.enabled", "true")
  end

  desc "run tests for plugins"
  Rake::TestTask.new :plugins  => :bootstrap do |t|
    t.libs << 'test'
    t.test_files = FileList["test/plugins/**/*test.rb"]
    java.lang.System.set_property("jruby.duby.enabled", "true")
  end

  desc "run jvm tests, both bytecode and java source"
  task :jvm do
    run_tests ["test:jvm:bytecode"]
  end

  namespace :jvm do
    task :test_setup =>  [:clean_tmp_test_directory, :build_test_fixtures]

    desc "run jvm tests compiling to bytecode"
    Rake::TestTask.new :bytecode => [:bootstrap, :test_setup] do |t|
      t.libs << 'test' <<'test/jvm'
      t.ruby_opts.concat ["-r", "bytecode_test_helper"]
      t.test_files = FileList["test/jvm/**/*test.rb"]
    end

    desc "run jvm tests using the new self hosted backend"
    task :new do
      run_tests ["test:jvm:new_backend", "test:jvm:mirrors"]
    end

    Rake::TestTask.new :new_backend => [:bootstrap, "javalib/mirah-compiler.jar", :test_setup] do |t|
      t.libs << 'test' << 'test/jvm'
      t.ruby_opts.concat ["-r", "new_backend_test_helper"]
      t.test_files = FileList["test/jvm/**/*test.rb"]
    end
    
    desc "run tests for mirror type system"
    Rake::TestTask.new :mirrors  => "javalib/mirah-mirrors.jar" do |t|
      t.libs << 'test'
      t.test_files = FileList["test/mirrors/**/*test.rb"]
    end
    Rake::TestTask.new :mirror_compilation  => "javalib/mirah-mirrors.jar" do |t|
      t.libs << 'test' << 'test/jvm'
      t.ruby_opts.concat ["-r", "mirror_compilation_test_helper"]
      t.test_files = FileList["test/jvm/**/*test.rb"]
    end
  end
end

task :clean_tmp_test_directory do
  FileUtils.rm_rf "tmp_test"
  FileUtils.mkdir_p "tmp_test"
end

task :build_test_fixtures do
  ant.javac 'destdir' => "tmp_test", 'srcdir' => 'test/fixtures',
    'includeantruntime' => false, 'debug' => true, 'listfiles' => true
end

task :init do
  mkdir_p 'dist'
  mkdir_p 'build'
end

desc "clean up build artifacts"
task :clean do
  ant.delete 'quiet' => true, 'dir' => 'build'
  ant.delete 'quiet' => true, 'dir' => 'dist'
  rm_f 'javalib/mirah-bootstrap.jar'
  rm_f 'javalib/mirah-builtins.jar'
  rm_f 'javalib/mirah-util.jar'
  rm_rf 'tmp'
end

task :compile => [:init, :bootstrap, :util, :jvm_backend]
task :util => 'javalib/mirah-util.jar'
task :jvm_backend => 'javalib/mirah-compiler.jar'

desc "build basic jar for distribution"
task :jar => :compile do
  ant.jar 'jarfile' => 'dist/mirah.jar' do
    fileset 'dir' => 'lib'
    fileset 'dir' => 'build'
    fileset 'dir' => '.', 'includes' => 'bin/*'
    fileset 'dir' => bitescript_lib_dir
    zipfileset 'src' => 'javalib/mirah-bootstrap.jar'
    zipfileset 'src' => 'javalib/mirah-builtins.jar'
    zipfileset 'src' => 'javalib/mirah-util.jar'
    zipfileset 'src' => 'javalib/mirah-compiler.jar'
    manifest do
      attribute 'name' => 'Main-Class', 'value' => 'org.mirah.MirahCommand'
    end
  end
end

namespace :jar do
  desc "build self-contained, complete jar"
  task :complete => :jar do
    ant.jar 'jarfile' => 'dist/mirah-complete.jar' do
      zipfileset 'src' => 'dist/mirah.jar'
      zipfileset 'src' => 'javalib/jruby-complete.jar'
      zipfileset 'src' => 'javalib/mirah-parser.jar'
      manifest do
        attribute 'name' => 'Main-Class', 'value' => 'org.mirah.MirahCommand'
      end
    end
  end

  desc "build bootstrap jar used by the gem"
  task :bootstrap => 'javalib/mirah-bootstrap.jar'
end

desc "Build a distribution zip file"
task :zip => 'jar:complete' do
  basedir = "tmp/mirah-#{Mirah::VERSION}"
  mkdir_p "#{basedir}/lib"
  mkdir_p "#{basedir}/bin"
  cp 'dist/mirah-complete.jar', "#{basedir}/lib"
  cp 'distbin/mirah.bash', "#{basedir}/bin/mirah"
  cp 'distbin/mirahc.bash', "#{basedir}/bin/mirahc"
  cp Dir['{distbin/*.bat}'], "#{basedir}/bin/"
  cp_r 'examples', "#{basedir}/examples"
  rm_rf "#{basedir}/examples/wiki"
  cp 'README.md', "#{basedir}"
  cp 'NOTICE', "#{basedir}"
  cp 'LICENSE', "#{basedir}"
  cp 'History.txt', "#{basedir}"
  sh "sh -c 'cd tmp ; zip -r ../dist/mirah-#{Mirah::VERSION}.zip mirah-#{Mirah::VERSION}/*'"
  rm_rf 'tmp'
end

desc "Build all redistributable files"
task :dist => [:gem, :zip]

file_create 'javalib/mirah-newast-transitional.jar' do
  require 'open-uri'
  puts "Downloading mirah-newast-transitional.jar"
  open('http://mirah.googlecode.com/files/mirah-newast-transitional.jar', 'rb') do |src|
    open('javalib/mirah-newast-transitional.jar', 'wb') do |dest|
      dest.write(src.read)
    end
  end
end

file 'javalib/mirah-bootstrap.jar' => ['javalib/mirah-newast-transitional.jar',
                                       'src/org/mirah/MirahClassLoader.java',
                                       'src/org/mirah/IsolatedResourceLoader.java',
                                       'src/org/mirah/MirahLogFormatter.mirah',
                                       'src/org/mirah/util/simple_diagnostics.mirah'] + 
                                      Dir['src/org/mirah/{macros,typer}/*.mirah'] +
                                      Dir['src/org/mirah/typer/simple/*.mirah'] +
                                      Dir['src/org/mirah/macros/anno/*.java'] do
  build_dir = 'build/bootstrap'
  rm_rf build_dir
  mkdir_p build_dir

  # Compile annotations and class loader
  ant.javac 'destdir' => build_dir, 'srcdir' => 'src',
    'includeantruntime' => false, 'debug' => true, 'listfiles' => true

  # Compile the Typer and Macro compiler
  bootstrap_mirahc('src/org/mirah/macros', 'src/org/mirah/MirahLogFormatter.mirah', 'src/org/mirah/typer',
                   'src/org/mirah/util/simple_diagnostics.mirah',
                   :classpath => ['javalib/mirah-parser.jar', 'build/bootstrap'],
                   :dest => build_dir
#                  :options => ['-V']
                   )
  add_quote_macro                    
  cp Dir['src/org/mirah/macros/*.tpl'], "#{build_dir}/org/mirah/macros"

  # Build the jar                    
  ant.jar 'jarfile' => 'javalib/mirah-bootstrap.jar' do
    fileset 'dir' => build_dir
  end
end


file 'javalib/mirah-util.jar' do
  require 'mirah'
  build_dir = 'build/util'
  rm_rf build_dir
  mkdir_p build_dir

  # build the Ruby sources
  puts "Compiling Ruby sources"
  JRuby::Compiler.compile_argv([
    '-t', build_dir,
    '--javac',
    'src/org/mirah/mirah_command.rb'
  ])

  # compile ant stuff
  ant_classpath = $CLASSPATH.grep(/ant/).map{|x| x.sub(/^file:/,'')}.join(File::PATH_SEPARATOR)
  sh *%W(jruby -Ilib bin/mirahc --classpath #{ant_classpath}:#{build_dir} --dest #{build_dir} src/org/mirah/ant)

  # compile invokedynamic stuff
  ant.javac 'destdir' => build_dir, 'srcdir' => 'src',
    'includes' => 'org/mirah/DynalangBootstrap.java',
    'classpath' => 'javalib/dynalink-0.1.jar:javalib/jsr292-mock.jar',
    'includeantruntime' => false

  # Build the jar
  ant.jar 'jarfile' => 'javalib/mirah-util.jar' do
    fileset 'dir' => build_dir
  end
end


file 'javalib/mirah-builtins.jar' => ['javalib/mirah-bootstrap.jar'] + Dir['src/org/mirah/builtins/*.mirah'] do
  rm_f 'javalib/mirah-builtins.jar'
  rm_rf 'build/builtins'
  mkdir_p 'build/builtins'
  sh *%w(jruby -Ilib bin/mirahc --dest build/builtins src/org/mirah/builtins)
  ant.jar 'jarfile' => 'javalib/mirah-builtins.jar' do
    fileset 'dir' => 'build/builtins'
  end
  rm_rf 'build/builtins'
end

file 'javalib/mirah-compiler.jar' => ['javalib/mirah-builtins.jar'] + Dir['src/org/mirah/{util,jvm/types,jvm/compiler}/*.mirah'] do
  rm_f 'javalib/mirah-compiler.jar'
  rm_rf 'build/compiler'
  mkdir_p 'build/compiler'
  phase3_files = Dir['src/org/mirah/jvm/compiler/{class,interface,script}_compiler.mirah'] + ['src/org/mirah/jvm/compiler/backend.mirah']
  phase2_files = Dir['src/org/mirah/jvm/compiler/{condition,method,string}_compiler.mirah']
  phase1_files = Dir['src/org/mirah/jvm/compiler/*.mirah'] - phase2_files - phase3_files
  sh *(%w(jruby -Ilib bin/mirahc --dest build/compiler ) +
       %w(--classpath javalib/mirah-parser.jar:javalib/mirah-bootstrap.jar) +
       %w(src/org/mirah/util src/org/mirah/jvm/types src/org/mirah/jvm/compiler/base_compiler.mirah))
  sh *(%w(jruby -Ilib bin/mirahc --dest build/compiler ) +
       %w(--classpath javalib/mirah-parser.jar:javalib/mirah-bootstrap.jar:build/compiler) +
       %w(src/org/mirah/util/context.mirah) + phase1_files)
  sh *(%w(jruby -Ilib bin/mirahc --dest build/compiler ) +
       %w(--classpath javalib/mirah-parser.jar:javalib/mirah-bootstrap.jar:build/compiler) +
       %w(src/org/mirah/util/context.mirah) + phase2_files)
  sh *(%w(jruby -Ilib bin/mirahc --dest build/compiler ) +
       %w(--classpath javalib/mirah-parser.jar:javalib/mirah-bootstrap.jar:build/compiler) +
       %w(src/org/mirah/util/context.mirah) + phase3_files)
  ant.jar 'jarfile' => 'javalib/mirah-compiler.jar' do
    fileset 'dir' => 'build/compiler'
  end
  rm_rf 'build/compiler'
end

file 'javalib/mirah-mirrors.jar' => ['javalib/mirah-compiler.jar'] + Dir['src/org/mirah/jvm/mirrors/**/*.mirah','src/org/mirah/jvm/model/**/*.mirah'] do
  rm_f 'javalib/mirah-mirrors.jar'
  rm_rf 'build/mirrors'
  mkdir_p 'build/mirrors'
  sh *(%w(jruby -Ilib bin/mirahc -N --dest build/mirrors ) +
       %w(--classpath javalib/mirah-parser.jar:javalib/mirah-bootstrap.jar:javalib/mirah-compiler.jar) +
       %w(src/org/mirah/jvm/mirrors/ src/org/mirah/jvm/model/))
  ant.jar 'jarfile' => 'javalib/mirah-mirrors.jar' do
    fileset 'dir' => 'build/mirrors'
  end
  rm_rf 'build/mirrors'
end

def find_jruby_jar
  require 'java'
  java_import 'org.jruby.Ruby'
  path = Ruby.java_class.resource('Ruby.class').toString
  path =~ %r{^jar:file:(.+)!/org/jruby/Ruby.class}
  $1
end

file 'javalib/mirahc.jar' => ['javalib/mirah-mirrors.jar',
                              'src/org/mirah/tool/mirahc.mirah',
                              ] do
  rm_f 'javalib/mirahc.jar'
  rm_rf 'build/mirahc'
  mkdir_p 'build/mirahc'
  sh *(%w(jruby -Ilib bin/mirahc -N --dest build/mirahc ) +
       %w(--classpath javalib/mirah-parser.jar:javalib/mirah-bootstrap.jar:javalib/mirah-compiler.jar:javalib/mirah-mirrors.jar) +
       %w(src/org/mirah/tool/))
  ant.jar :jarfile => 'javalib/mirahc.jar' do
    fileset :dir => 'build/mirahc'
    zipfileset :src => 'javalib/mirah-bootstrap.jar'
    zipfileset :src => 'javalib/mirah-builtins.jar'
    zipfileset :src => 'javalib/mirah-util.jar'
    zipfileset :src => 'javalib/mirah-compiler.jar'
    zipfileset :src => 'javalib/mirah-mirrors.jar'
    zipfileset :src => find_jruby_jar, :includes => 'org/jruby/org/objectweb/**/*'
    zipfileset :src => 'javalib/mirah-parser.jar'
    manifest do
      attribute :name => 'Main-Class', :value => 'org.mirah.tool.Mirahc'
    end
  end
end

if Float(JRUBY_VERSION[0..2]) >= 1.7
  require 'bitescript'
  class Annotater < BiteScript::ASM::ClassVisitor
    def initialize(filename, &block)
      cr = BiteScript::ASM::ClassReader.new(java.io.FileInputStream.new(filename))
      cw = BiteScript::ASM::ClassWriter.new(0)
      super(BiteScript::ASM::Opcodes::ASM4, cw)
      @block = block
      cr.accept(self, 0)
      f = java.io.FileOutputStream.new(filename)
      f.write(cw.toByteArray)
      f.close
    end
    def visitSource(*args); end
    def visit(version, access, name, sig, superclass, interfaces)
      super
      @block.call(self)
    end
  end
end

def add_quote_macro
  raise "Can't compile on JRuby less than 1.7" unless defined?(Annotater)
  Annotater.new('build/bootstrap/org/mirah/macros/QuoteMacro.class') do |klass|
    av = klass.visitAnnotation('Lorg/mirah/macros/anno/MacroDef;', true)
    av.visit("name", "quote")
    args = av.visitAnnotation('arguments', 'Lorg/mirah/macros/anno/MacroArgs;')
    req = args.visitArray('required')
    req.visit(nil, 'mirah.lang.ast.Block')
    req.visitEnd
    args.visitEnd
    av.visitEnd
  end
  Annotater.new('build/bootstrap/org/mirah/macros/CompilerQuoteMacro.class') do |klass|
    av = klass.visitAnnotation('Lorg/mirah/macros/anno/MacroDef;', true)
    av.visit("name", "quote")
    args = av.visitAnnotation('arguments', 'Lorg/mirah/macros/anno/MacroArgs;')
    req = args.visitArray('required')
    req.visit(nil, 'mirah.lang.ast.Block')
    req.visitEnd
    args.visitEnd
    av.visitEnd
  end
  Annotater.new('build/bootstrap/org/mirah/macros/Macro.class') do |klass|
    av = klass.visitAnnotation('Lorg/mirah/macros/anno/Extensions;', false)
    macros = av.visitArray('macros')
    macros.visit(nil, 'org.mirah.macros.QuoteMacro')
    macros.visitEnd
    av.visitEnd
  end
  Annotater.new('build/bootstrap/org/mirah/macros/Compiler.class') do |klass|
    av = klass.visitAnnotation('Lorg/mirah/macros/anno/Extensions;', false)
    macros = av.visitArray('macros')
    macros.visit(nil, 'org.mirah.macros.CompilerQuoteMacro')
    macros.visitEnd
    av.visitEnd
  end
end

def bootstrap_mirahc(*paths)
  options = if paths[-1].kind_of?(Hash)
    paths.pop
  else
    {}
  end
  args = options[:options] || []
  if options[:classpath]
    args << '--classpath' << options[:classpath].map {|p| File.expand_path(p)}.join(File::PATH_SEPARATOR)
  end
  args << '-d' << File.expand_path(options[:dest]) << '--jvm' << '1.5'
  jarfile = File.expand_path('javalib/mirah-newast-transitional.jar')
  Dir.chdir(options[:dir] || '.') do
    runjava(jarfile, 'compile', *(args + paths))
  end
end

def runjava(jar, *args)
  sh 'java', '-jar', jar, *args
  unless $?.success?
    exit $?.exitstatus
  end
end
