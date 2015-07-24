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
task :new_ci => [:'test:core', :'test:jvm', :'test:artifacts', 'dist/mirahc3.jar']

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
    task :test_setup =>  [:clean_tmp_test_classes, :build_test_fixtures]

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

task :clean_tmp_test_classes do
  FileUtils.rm_rf "tmp_test/test_classes"
  FileUtils.mkdir_p "tmp_test/test_classes"
end



task :build_test_fixtures => 'tmp_test/fixtures/fixtures_built.txt'
directory 'tmp_test/fixtures'
file 'tmp_test/fixtures/fixtures_built.txt' => ['tmp_test/fixtures'] + Dir['test/fixtures/**/*.java'] do
  `touch tmp_test/fixtures/fixtures_built.txt`
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
  rm_rf 'tmp_test'
  rm_rf 'pkg'
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

file_create 'javalib/asm-5.jar' do
  require 'open-uri'
  puts "Downloading asm-5.jar"
  url = 'https://search.maven.org/remotecontent?filepath=org/ow2/asm/asm-all/5.0.3/asm-all-5.0.3.jar'
  open(url, 'rb') do |src|
    open('javalib/asm-5.jar', 'wb') do |dest|
      dest.write(src.read)
    end
  end
end

file_create 'javalib/mirahc-prev.jar' do
  require 'open-uri'
  url = 'https://search.maven.org/remotecontent?filepath=org/mirah/mirah/0.1.3/mirah-0.1.3.jar'

  puts "Downloading mirahc-prev.jar from #{url}"

  open(url, 'rb') do |src|
    open('javalib/mirahc-prev.jar', 'wb') do |dest|
      dest.write(src.read)
    end
  end
end

def build_jar(new_jar,build_dir)
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

def bootstrap_mirah_from(old_jar, new_jar)
  
  #typer_srcs = Dir['src/org/mirah/typer/**/*.mirah'].sort
  #typer_classes = typer_srcs.map {|s| s.sub 'src', build_dir }
if false
  name = new_jar.sub /[.\/]/, '_'

  
  java_build_dir = "build/#{name}-java"
  java_jar = "#{java_build_dir}.jar"
  file java_jar => Dir["src/**/*.java"].sort do
    rm_rf java_build_dir
    mkdir_p java_build_dir

    # Compile Java sources
    ant.javac 'source' => '1.6',
              'target' => '1.6',
              'destdir' => java_build_dir,
              'srcdir' => 'src',
              'includeantruntime' => false,
              'debug' => true,
              'listfiles' => true
    ant.jar 'jarfile' => java_jar do
      fileset 'dir' => java_build_dir
    end
  end

  bootstrap_build_dir = "build/#{name}-bootstrap"
  bootstrap_jar = "#{bootstrap_build_dir}.jar"
  bootstrap_srcs = Dir['src/org/mirah/{builtins,jvm/types,macros,util,}/*.mirah'].sort
  file bootstrap_jar => bootstrap_srcs do
    build_mirah_stuff old_jar, bootstrap_build_dir, bootstrap_srcs
    ant.jar 'jarfile' => bootstrap_jar do
      fileset 'dir' => bootstrap_build_dir
    end
  end

  typer_build_dir = "build/#{name}-typer"
  typer_jar = "#{typer_build_dir}.jar"
  file typer_jar => Dir['src/org/mirah/typer/**/*.mirah'].sort do
    build_mirah_stuff old_jar, typer_build_dir, typer_srcs
    ant.jar 'jarfile' => typer_jar do
      fileset 'dir' => typer_build_dir
    end
  end

  compiler_build_dir = "build/#{name}-compiler"
  compiler_jar = "#{compiler_build_dir}.jar"
  file compiler_jar => Dir['src/org/mirah/jvm/{compiler,mirrors,model}/**/*.mirah'].sort do
    build_mirah_stuff old_jar, compiler_build_dir, compiler_srcs
    ant.jar 'jarfile' => compiler_jar do
      fileset 'dir' => compiler_build_dir
    end
  end

  tool_build_dir = "build/#{name}-tool"
  tool_jar = "#{tool_build_dir}.jar"
  file tool_jar => Dir['src/org/mirah/tool/**/*.mirah'].sort do
    build_mirah_stuff old_jar, tool_build_dir, tool_srcs
    ant.jar 'jarfile' => tool_jar do
      fileset 'dir' => tool_build_dir
    end
  end

  ant_build_dir = "build/#{name}-ant"
  ant_jar = "#{ant_build_dir}.jar"
  file ant_jar => Dir['src/org/mirah/ant/**/*.mirah'].sort do
    build_mirah_stuff old_jar, ant_build_dir, ant_srcs
    ant.jar 'jarfile' => ant_jar do
      fileset 'dir' => ant_build_dir
    end
  end
  jars = [java_jar, bootstrap_jar, typer_jar, compiler_jar, tool_jar, ant_jar]
  file new_jar => jars +
                  [old_jar, 'javalib/asm-5.jar', 'javalib/mirah-parser.jar'] do
    ant.jar 'jarfile' => new_jar do
      jars.each {|j| zipfileset 'src' => j }
      zipfileset 'src' => 'javalib/asm-5.jar', 'includes' => 'org/objectweb/**/*'
      zipfileset 'src' => 'javalib/mirah-parser.jar'
      metainf 'dir' => File.dirname(__FILE__), 'includes' => 'LICENSE,COPYING,NOTICE'
      manifest do
        attribute 'name' => 'Main-Class', 'value' => 'org.mirah.MirahCommand'
      end
    end

  end

else # original

  naked_mirahc_jar = new_jar.sub(".jar","-naked.jar")

  mirah_srcs = Dir['src/org/mirah/{jvm/types,macros,util,}/*.mirah'].sort +
               Dir['src/org/mirah/builtins/builtins.mirah'] +
               Dir['src/org/mirah/typer/**/*.mirah'].sort +
               Dir['src/org/mirah/jvm/{compiler,mirrors,model}/**/*.mirah'].sort +
               Dir['src/org/mirah/tool/*.mirah'].sort

  extensions_srcs = Dir['src/org/mirah/builtins/*_extensions.mirah'].sort
  ant_srcs        =    ['src/org/mirah/ant/compile.mirah']

  file new_jar => mirah_srcs + extensions_srcs + ant_srcs + [old_jar, 'javalib/asm-5.jar', 'javalib/mirah-parser.jar'] do
    build_dir = 'build/bootstrap'+new_jar.gsub(/[.-\/]/, '_')
    rm_rf build_dir
    mkdir_p build_dir

    # Compile Java sources
    ant.javac 'source' => '1.6',
              'target' => '1.6',
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

    default_class_path = ["javalib/mirah-parser.jar", build_dir, "javalib/asm-5.jar"].join(File::PATH_SEPARATOR)


    # Compile Mirah sources
    runjava('-Xmx512m',
            old_jar,
            '-d', build_dir,
            '-classpath', default_class_path,
            '--jvm', build_version,
            
            #'--verbose',

            *mirah_srcs)
  
    build_jar(naked_mirahc_jar,build_dir)

      # compile ant stuff
      ant_classpath = $CLASSPATH.grep(/ant/).map{|x| x.sub(/^file:/,'')}.join(File::PATH_SEPARATOR)
      runjava '-Xmx512m',
            old_jar,
            '-d', build_dir,
            '-classpath', [default_class_path, ant_classpath].join(File::PATH_SEPARATOR),
            '--jvm', build_version,
            'src/org/mirah/ant'

    # compile extensions stuff
    runjava('-Xmx512m', '-Dorg.mirah.builtins.enabled=false', naked_mirahc_jar, '-d', build_dir, '-classpath', default_class_path, '--jvm', build_version, *extensions_srcs)

    build_jar(new_jar,build_dir)
  end
end # feature flag
end

def build_mirah_stuff old_jar, build_dir, mirah_srcs

    rm_rf build_dir
    mkdir_p build_dir


    # mirahc needs to be 1.7 or lower
    build_version = java.lang.System.getProperty('java.specification.version')
    if build_version.to_f > 1.7
      build_version = '1.7'
    end

    default_class_path = ["javalib/mirah-parser.jar", build_dir,"javalib/asm-5.jar"].join(File::PATH_SEPARATOR)

    # Compile Mirah sources
    runjava('-Xmx512m',
            old_jar,
            '-d', build_dir,
            '-classpath', default_class_path,
            '--jvm', build_version,
            *mirah_srcs)


  
      # compile ant stuff
#      ant_classpath = $CLASSPATH.grep(/ant/).map{|x| x.sub(/^file:/,'')}.join(File::PATH_SEPARATOR)
#      runjava '-Xmx512m',
#            old_jar,
#            '-d', build_dir,
#            '-classpath', [default_class_path, ant_classpath].join(File::PATH_SEPARATOR),
#            '--jvm', build_version,
#            'src/org/mirah/ant'

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

bootstrap_mirah_from('javalib/mirahc-prev.jar', 'dist/mirahc.jar')
bootstrap_mirah_from('dist/mirahc.jar', 'dist/mirahc2.jar')
bootstrap_mirah_from('dist/mirahc2.jar', 'dist/mirahc3.jar')


def runjava(jar, *args)
  sh 'java', '-jar', jar, *args
  unless $?.success?
    exit $?.exitstatus
  end
end
