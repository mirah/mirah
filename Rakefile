# Copyright (c) 2010-2014 The Mirah project authors. All Rights Reserved.
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
begin
  require 'bundler/setup'
rescue LoadError
  puts "couldn't load bundler. Check your environment."
end
require 'rake'
require 'rake/testtask'
require 'rubygems'
require 'rubygems/package_task'
require 'java'
require 'jruby/compiler'
require 'ant'

#TODO update downloads st build reqs that are not run reqs go in a different dir
# put run reqs in javalib
# final artifacts got in dist

# this definition ensures that the bootstrap tasks will be completed before
# building the .gem file. Otherwise, the gem may not contain the jars.
task :gem => :compile

Gem::PackageTask.new Gem::Specification.load('mirah.gemspec') do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

task :default => :new_ci

desc "run new backend ci"
task :new_ci => [:'test:core', :'test:jvm', :'test:artifacts']

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
  run_tests [ 'test:core', 'test:plugins', 'test:jvm', 'test:artifacts' ]
end

namespace :test do

  desc "run the core tests"
  Rake::TestTask.new :core  => :compile do |t|
    t.libs << 'test'
    t.test_files = FileList["test/core/**/*test.rb"]
    java.lang.System.set_property("jruby.duby.enabled", "true")
  end

  desc "run tests for plugins"
  Rake::TestTask.new :plugins  => :compile do |t|
    t.libs << 'test'
    t.test_files = FileList["test/plugins/**/*test.rb"]
    java.lang.System.set_property("jruby.duby.enabled", "true")
  end

  desc "run the artifact tests"
  Rake::TestTask.new :artifacts  => :compile do |t|
    t.libs << 'test'
    t.test_files = FileList["test/artifacts/**/*test.rb"]
  end


  desc "run jvm tests"
  task :jvm => 'test:jvm:all'

  namespace :jvm do
    task :test_setup =>  [:clean_tmp_test_directory, :build_test_fixtures]

    desc "run jvm tests using the new self hosted backend"
    task :all do
      run_tests ["test:jvm:mirror_compilation", "test:jvm:mirrors"]
    end
    
    desc "run tests for mirror type system"
    Rake::TestTask.new :mirrors  => "dist/mirahc.jar" do |t|
      t.libs << 'test'
      t.test_files = FileList["test/mirrors/**/*test.rb"]
    end

    Rake::TestTask.new :mirror_compilation  => ["dist/mirahc.jar", :test_setup] do |t|
      t.libs << 'test' << 'test/jvm'
      t.ruby_opts.concat ["-r", "new_backend_test_helper"]
      t.test_files = FileList["test/jvm/**/*test.rb"]
    end
  end
end

task :clean_tmp_test_directory do
  FileUtils.rm_rf "tmp_test"
  FileUtils.mkdir_p "tmp_test"
  FileUtils.mkdir_p "tmp_test/test_classes"
  FileUtils.mkdir_p "tmp_test/fixtures"
end

task :build_test_fixtures do
  ant.javac 'destdir' => "tmp_test/fixtures",
            'srcdir' => 'test/fixtures',
            'includeantruntime' => false,
            'debug' => true,
            'listfiles' => true
end

task :init do
  mkdir_p 'dist'
  mkdir_p 'build'
end

desc "clean up build artifacts"
task :clean do
  ant.delete 'quiet' => true, 'dir' => 'build'
  ant.delete 'quiet' => true, 'dir' => 'dist'
  rm_f 'dist/mirahc.jar'
  rm_rf 'tmp'
end

desc "clean downloaded dependencies"
task :clean_downloads do
  rm_f "javalib/mirahc-prev.jar"
  rm_f 'javalib/jruby-complete.jar'
  rm_f 'javalib/asm-5.jar'
end

task :compile => 'dist/mirahc.jar'
task :jvm_backend => 'dist/mirahc.jar'

desc "build backwards-compatible ruby jar"
task :jar => :compile do
  ant.jar 'jarfile' => 'dist/mirah.jar' do
    fileset 'dir' => 'lib'
    fileset 'dir' => 'build'
    fileset 'dir' => '.', 'includes' => 'bin/*'
    zipfileset 'src' => 'dist/mirahc.jar'
    manifest do
      attribute 'name' => 'Main-Class', 'value' => 'org.mirah.MirahCommand'
    end
  end
end

namespace :jar do
  desc "build self-contained, complete ruby jar"
  task :complete => [:jar, 'javalib/asm-5.jar'] do
    ant.jar 'jarfile' => 'dist/mirah-complete.jar' do
      zipfileset 'src' => 'dist/mirah.jar'
      zipfileset 'src' => 'javalib/asm-5.jar'
      manifest do
        attribute 'name' => 'Main-Class', 'value' => 'org.mirah.MirahCommand'
      end
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
  cp 'README.md', "#{basedir}"
  cp 'NOTICE', "#{basedir}"
  cp 'LICENSE', "#{basedir}"
  cp 'COPYING', "#{basedir}"
  cp 'History.txt', "#{basedir}"
  sh "sh -c 'cd tmp ; zip -r ../dist/mirah-#{Mirah::VERSION}.zip mirah-#{Mirah::VERSION}/*'"
  rm_rf 'tmp'
end

desc "Build all redistributable files"
task :dist => [:gem, :zip]

#TODO find/create ssl location for this jar 
file_create 'javalib/asm-5.jar' do
  require 'open-uri'
  puts "Downloading asm-5.jar"
  open('http://central.maven.org/maven2/org/ow2/asm/asm-all/5.0.3/asm-all-5.0.3.jar', 'rb') do |src|
    open('javalib/asm-5.jar', 'wb') do |dest|
      dest.write(src.read)
    end
  end
end

file_create 'javalib/mirahc-prev.jar' do
  require 'open-uri'
  url = 'http://search.maven.org/remotecontent?filepath=org/mirah/mirah/0.1.3/mirah-0.1.3.jar'

  puts "Downloading mirahc-prev.jar from #{url}"

  open(url, 'rb') do |src|
    open('javalib/mirahc-prev.jar', 'wb') do |dest|
      dest.write(src.read)
    end
  end
end


def bootstrap_mirah_from(old_jar, new_jar)
  mirah_srcs = Dir['src/org/mirah/{builtins,jvm/types,macros,util,}/*.mirah'].sort +
               Dir['src/org/mirah/typer/**/*.mirah'].sort +
               Dir['src/org/mirah/jvm/{compiler,mirrors,model}/**/*.mirah'].sort +
               Dir['src/org/mirah/tool/*.mirah'].sort
  file new_jar => mirah_srcs + [old_jar, 'javalib/asm-5.jar', 'javalib/mirah-parser.jar'] do
    build_dir = 'build/bootstrap'
    rm_rf build_dir
    mkdir_p build_dir

    # Compile Java sources
    ant.javac 'source' => '1.5',
              'target' => '1.5',
              'destdir' => build_dir,
              'srcdir' => 'src',
              'includeantruntime' => false,
              'debug' => true,
              'listfiles' => true

    # mirahc needs to be 1.7 or lower
    build_version = java.lang.System.getProperty('java.specification.version')
    if build_version.to_f > 1.7
      build_version = '1.7'
    end
    # Compile Mirah sources
    runjava('-Xmx512m',
            old_jar,
            '-d', build_dir,
            '-classpath', "javalib/mirah-parser.jar:#{build_dir}:javalib/asm-5.jar",
            '--jvm', build_version,
            *mirah_srcs)
  
    # Build the jar                    
    ant.jar 'jarfile' => new_jar do
      fileset 'dir' => build_dir
      zipfileset 'src' => 'javalib/asm-5.jar', 'includes' => 'org/objectweb/**/*'
      zipfileset 'src' => 'javalib/mirah-parser.jar'
      metainf 'dir' => File.dirname(__FILE__), 'includes' => 'LICENSE,COPYING,NOTICE'
      manifest do
        attribute 'name' => 'Main-Class', 'value' => 'org.mirah.MirahCommand'
      end
    end
  end
end

bootstrap_mirah_from('javalib/mirahc-prev.jar', 'dist/mirahc.jar')
bootstrap_mirah_from('dist/mirahc.jar', 'dist/mirahc2.jar')
bootstrap_mirah_from('dist/mirahc2.jar', 'dist/mirahc3.jar')


def runjava(jar, *args)
  sh 'java', '-jar', jar, *args
  unless $?.success?
    exit $?.exitstatus
  end
end
