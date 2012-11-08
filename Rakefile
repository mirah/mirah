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

task :gem => 'jar:bootstrap'
task :bootstrap => ['javalib/mirah-bootstrap.jar', 'javalib/mirah-builtins.jar']
task :default => :'test:jvm:bytecode'
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
  run_tests [ 'test:core', 'test:plugins', 'test:jvm' ]
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
    desc "run jvm tests compiling to bytecode"
    Rake::TestTask.new :bytecode => :bootstrap do |t|
      t.libs << 'test' <<'test/jvm'
      t.ruby_opts.concat ["-r", "bytecode_test_helper"]
      t.test_files = FileList["test/jvm/**/*test.rb"]
    end
  end
end

task :init do
  mkdir_p 'dist'
  mkdir_p 'build'
end

desc "clean up build artifacts"
task :clean do
  ant.delete :quiet => true, :dir => 'build'
  ant.delete :quiet => true, :dir => 'dist'
  rm 'javalib/mirah-bootstrap.jar'
  rm 'javalib/mirah-builtins.jar'
end

task :compile => [:init, :bootstrap] do
  require 'mirah'
  # build the Ruby sources
  puts "Compiling Ruby sources"
  JRuby::Compiler.compile_argv([
    '-t', 'build',
    '--javac',
    'src/org/mirah/mirah_command.rb'
  ])

  # compile ant stuff
  ant_classpath = $CLASSPATH.grep(/ant/).map{|x| x.sub(/^file:/,'')}.join(File::PATH_SEPARATOR)
  sh *%W(jruby -Ilib bin/mirahc --classpath #{ant_classpath}:build --dest build src/org/mirah/ant)

  # compile invokedynamic stuff
  ant.javac :destdir => 'build', :srcdir => 'src',
    :includes => 'org/mirah/DynalangBootstrap.java',
    :classpath => 'javalib/dynalink-0.1.jar:javalib/jsr292-mock.jar',
    :includeantruntime => false
end

desc "build basic jar for distribution"
task :jar => :compile do
  ant.jar :jarfile => 'dist/mirah.jar' do
    fileset :dir => 'lib'
    fileset :dir => 'build'
    fileset :dir => '.', :includes => 'bin/*'
    fileset :dir => bitescript_lib_dir
    zipfileset :src => 'javalib/mirah-bootstrap.jar'
    zipfileset :src => 'javalib/mirah-builtins.jar'
    manifest do
      attribute :name => 'Main-Class', :value => 'org.mirah.MirahCommand'
    end
  end
end

namespace :jar do
  desc "build self-contained, complete jar"
  task :complete => :jar do
    ant.jar :jarfile => 'dist/mirah-complete.jar' do
      zipfileset :src => 'dist/mirah.jar'
      zipfileset :src => 'javalib/jruby-complete.jar'
      zipfileset :src => 'javalib/mirah-parser.jar'
      zipfileset :src => 'javalib/dynalink-0.2.jar'
      manifest do
        attribute :name => 'Main-Class', :value => 'org.mirah.MirahCommand'
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
  cp 'README.txt', "#{basedir}"
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
                                       'src/org/mirah/MirahLogFormatter.mirah'] + 
                                      Dir['src/org/mirah/{macros,typer}/*.mirah'] +
                                      Dir['src/org/mirah/typer/simple/*.mirah'] +
                                      Dir['src/org/mirah/macros/anno/*.java'] do
  rm_rf 'build/bootstrap'
  mkdir_p 'build/bootstrap'

  # Compile annotations and class loader
  ant.javac :destdir => 'build/bootstrap', :srcdir => 'src',
    :includeantruntime => false, :debug => true, :listfiles => true

  # Compile the Typer and Macro compiler
  bootstrap_mirahc('src/org/mirah/macros', 'src/org/mirah/MirahLogFormatter.mirah', 'src/org/mirah/typer',
                    :classpath => ['javalib/mirah-parser.jar', 'build/bootstrap'],
                    :dest => 'build/bootstrap'
#                    :options => ['-V']
                    )
  add_quote_macro                    
  cp Dir['src/org/mirah/macros/*.tpl'], 'build/bootstrap/org/mirah/macros'

  # Build the jar                    
  ant.jar :jarfile => 'javalib/mirah-bootstrap.jar' do
    fileset :dir => 'build/bootstrap'
  end

  rm_rf 'build/bootstrap'
end

file 'javalib/mirah-builtins.jar' => ['javalib/mirah-bootstrap.jar'] + Dir['src/org/mirah/builtins/*.mirah'] do
  rm_f 'javalib/mirah-builtins.jar'
  rm_rf 'build/builtins'
  mkdir_p 'build/builtins'
  sh *%w(jruby -Ilib bin/mirahc --dest build/builtins src/org/mirah/builtins)
  ant.jar :jarfile => 'javalib/mirah-builtins.jar' do
    fileset :dir => 'build/builtins'
  end
  rm_rf 'build/builtins'
end

require 'bitescript'
class Annotater < BiteScript::ASM::ClassWriter
  def initialize(filename, &block)
    cr = BiteScript::ASM::ClassReader.new(java.io.FileInputStream.new(filename))
    super(cr, 0)
    @block = block
    cr.accept(self, 0)
    f = java.io.FileOutputStream.new(filename)
    f.write(toByteArray)
    f.close
  end
  def visitSource(*args); end
  def visit(*args)
    super
    @block.call(self)
  end
end

def add_quote_macro
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
  Annotater.new('build/bootstrap/org/mirah/macros/Macro.class') do |klass|
    av = klass.visitAnnotation('Lorg/mirah/macros/anno/Extensions;', false)
    macros = av.visitArray('macros')
    macros.visit(nil, 'org.mirah.macros.QuoteMacro')
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
  args << '-d' << File.expand_path(options[:dest])
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
