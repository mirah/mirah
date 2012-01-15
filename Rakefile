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

task :default => :test
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
  Rake::TestTask.new :core do |t|
    t.libs << 'test'
    t.test_files = FileList["test/core/**/*test.rb"]
    java.lang.System.set_property("jruby.duby.enabled", "true")
  end
  
  desc "run tests for plugins"
  Rake::TestTask.new :plugins do |t|
    t.libs << 'test'
    t.test_files = FileList["test/plugins/**/*test.rb"]
    java.lang.System.set_property("jruby.duby.enabled", "true")
  end

  desc "run jvm tests, both bytecode and java source"
  task :jvm do
    run_tests ["test:jvm:bytecode", "test:jvm:javac"]
  end
  
  namespace :jvm do
    desc "run jvm tests compiling to bytecode"
    Rake::TestTask.new :bytecode do |t|
      t.libs << 'test' <<'test/jvm'
      t.ruby_opts.concat ["-r", "bytecode_test_helper"]
      t.test_files = FileList["test/jvm/**/*test.rb"]
      java.lang.System.set_property("jruby.duby.enabled", "true")
    end
    
    desc "run jvm tests compiling to java source, then bytecode"
    Rake::TestTask.new :javac do |t|
      t.libs << 'test' <<'test/jvm'
      t.ruby_opts.concat ["-r", "javac_test_helper"]
      t.test_files = FileList["test/jvm/**/*test.rb"]
      java.lang.System.set_property("jruby.duby.enabled", "true")
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
end

task :compile => :init do
  require 'mirah'
  # build the Ruby sources
  puts "Compiling Ruby sources"
  JRuby::Compiler.compile_argv([
    '-t', 'build',
    '--javac',
    'src/org/mirah/mirah_command.rb'
  ])

  # build the Mirah sources
  puts "Compiling Mirah sources"
  Dir.chdir 'src' do
    classpath = Mirah::Env.encode_paths([
        'javalib/jruby-complete.jar',
        'javalib/JRubyParser.jar',
        'build',
        '/usr/share/ant/lib/ant.jar'
      ])
    Mirah.compile(
      '-c', classpath,
      '-d', '../build',
      '--jvm', '1.6',
      'org/mirah',
      'duby/lang',
      'mirah'
      )
  end
  
  # compile invokedynamic stuff
  ant.javac :destdir => 'build', :srcdir => 'src',
    :includes => 'org/mirah/DynalangBootstrap.java',
    :classpath => 'javalib/dynalink-0.1.jar:javalib/jsr292-mock.jar'
end

desc "build basic jar for distribution"
task :jar => :compile do
  ant.jar :jarfile => 'dist/mirah.jar' do
    fileset :dir => 'lib'
    fileset :dir => 'build'
    fileset :dir => '.', :includes => 'bin/*'
    fileset :dir => bitescript_lib_dir
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
  task :bootstrap => :compile do
    ant.jar :jarfile => 'javalib/mirah-bootstrap.jar' do
      fileset :dir => 'build'
    end
  end
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
