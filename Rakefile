# Copyright (c) 2010-2016 The Mirah project authors. All Rights Reserved.
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

# We use jarjar to do some rewritting of packages in the parser.
ant.taskdef 'name' => 'jarjar',
            'classpath' => 'mirah-parser/javalib/jarjar-1.1.jar',
            'classname'=>"com.tonicsystems.jarjar.JarJarTask"

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
task :new_ci => [:'test:core',
                 :'test:jvm',
                 :'test:artifacts',
                 'dist/mirahc3.jar',
                 :'test:parser']

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
  run_tests [ 'test:core', 'test:plugins', 'test:jvm', 'test:artifacts', 'test:parser' ]
end

namespace :test do

  desc "run parser tests"
  Rake::TestTask.new :parser => ['build/mirah-parser.jar'] do |t|
    #t.libs << 'mirah-parser/test'
    t.test_files = FileList["mirah-parser/test/**/test*.rb"]
    # TODO is the duby enabled even doing anything?
    java.lang.System.set_property("jruby.duby.enabled", "true")
  end


  desc "run the core tests"
  Rake::TestTask.new :core => :compile do |t|
    t.libs << 'test'
    t.test_files = FileList["test/core/**/*test.rb"]
    java.lang.System.set_property("jruby.duby.enabled", "true")
  end

  desc "run tests for plugins"
  Rake::TestTask.new :plugins => :compile do |t|
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

  javac_args = {
      'destdir' => "tmp_test/fixtures",
      'srcdir' => 'test/fixtures',
      'includeantruntime' => false,
      'debug' => true,
      'listfiles' => true
  }
  jvm_version = java.lang.System.getProperty('java.specification.version').to_f

  javac_args['excludes'] = '**/*Java8.java' if jvm_version < 1.8
  ant.javac javac_args
  `touch tmp_test/fixtures/fixtures_built.txt`
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
    # TODO this is wrong. :(
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
  url = 'https://search.maven.org/remotecontent?filepath=org/ow2/asm/asm-all/5.0.4/asm-all-5.0.4.jar'
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

def bootstrap_mirah_from(old_jar, new_jar)
  name = new_jar.gsub /[\.\/]/, '_'

  # Compile Java parts of the compiler.
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

  core_build_dir = "build/#{name}-core"
  core_jar = "#{core_build_dir}.jar"
  core_mirah_srcs = Dir['src/org/mirah/*.mirah'].sort +
                    Dir['src/org/mirah/{jvm/types,macros,util}/*.mirah'].sort +
                    Dir['src/org/mirah/typer/**/*.mirah'].sort +
                    Dir['src/org/mirah/jvm/{compiler,mirrors,model}/**/*.mirah'].sort -
                     # org.mirah.MirahCommand depends on .tool., so remove from core
                    ['src/org/mirah/mirah_command.mirah']

  file core_jar => core_mirah_srcs + [java_jar, old_jar, 'javalib/asm-5.jar'] do
    compile_mirah_with_jar old_jar, core_build_dir, core_mirah_srcs, [java_jar]
    ant.jar 'jarfile' => core_jar do
      fileset 'dir' => core_build_dir
    end
  end

  # Tool jar rule.
  tool_mirah_srcs = Dir['src/org/mirah/tool/*.mirah'].sort + 
                    ['src/org/mirah/mirah_command.mirah'] # add it back in here.
  tool_build_dir = "build/#{name}-tool"
  tool_jar = "#{tool_build_dir}.jar"
  file tool_jar => tool_mirah_srcs + [core_jar, old_jar, 'javalib/asm-5.jar'] do
    compile_mirah_with_jar old_jar, tool_build_dir, tool_mirah_srcs, [core_jar, java_jar]
    ant.jar 'jarfile' => tool_jar do
      fileset 'dir' => tool_build_dir
    end
  end

  # Ant jar rule.
  ant_mirah_srcs = Dir['src/org/mirah/ant/*.mirah'].sort
  ant_build_dir = "build/#{name}-ant"
  ant_jar = "#{ant_build_dir}.jar"
  file ant_jar => ant_mirah_srcs + [core_jar, tool_jar, java_jar, old_jar, 'javalib/asm-5.jar'] do
    ant_classpath = $CLASSPATH.grep(/ant/).map{|x| x.sub(/^file:/,'')}
    compile_mirah_with_jar old_jar, ant_build_dir, ant_mirah_srcs, [core_jar, tool_jar, java_jar] + ant_classpath
    ant.jar 'jarfile' => ant_jar do
      fileset 'dir' => ant_build_dir
    end
  end

  # Extensions
  # NB: we compile extensions with the current version of the compiler.
  #
  extensions_mirah_srcs = Dir['src/org/mirah/builtins/*.mirah'].sort
  extensions_build_dir = "build/#{name}-extensions"
  extensions_jar = "#{extensions_build_dir}.jar"
  file extensions_jar => extensions_mirah_srcs + [core_jar, tool_jar, java_jar, 'javalib/asm-5.jar'] do

    classpath = [core_jar, tool_jar, java_jar,
                 "javalib/mirah-parser.jar", # TODO hook into built parser.
                 "javalib/asm-5.jar"].join(File::PATH_SEPARATOR)

    runjava('-Xmx512m', 
            '-classpath', classpath,
            'org.mirah.MirahCommand',
            '-d', extensions_build_dir,
            '-classpath', classpath,
            '--jvm', build_version,
            *extensions_mirah_srcs)
    ant.jar 'jarfile' => extensions_jar do
      fileset 'dir' => extensions_build_dir
      # TODO clean up
      #metainf 'dir' => File.dirname(__FILE__), 'includes' => 'LICENSE,COPYING,NOTICE'
      metainf 'dir' => File.dirname(__FILE__)+'/src/org/mirah/builtins', 
              'includes' => 'services/*'
    end
  end
  jars = [java_jar, core_jar, tool_jar, ant_jar, extensions_jar]
  file new_jar => jars +
                  [old_jar, 'javalib/asm-5.jar', 'javalib/mirah-parser.jar'] do
    # TODO use ant.jarjarto shade asm-5 in the fat jar
    ant.jar 'jarfile' => new_jar do
      jars.each {|j| zipfileset 'src' => j }
      zipfileset 'src' => 'javalib/asm-5.jar', 'includes' => 'org/objectweb/**/*'
      zipfileset 'src' => 'javalib/mirah-parser.jar'
      metainf 'dir' => File.dirname(__FILE__), 'includes' => 'LICENSE,COPYING,NOTICE'
      metainf 'dir' => File.dirname(__FILE__)+'/src/org/mirah/builtins', 
              'includes' => 'services/*'

      manifest do
        attribute 'name' => 'Main-Class', 'value' => 'org.mirah.MirahCommand'
      end
    end
  end
end

# compiles to the build dir
def compile_mirah_with_jar old_jar, build_dir, mirah_srcs, classpath=[], clean=true
    if clean
      puts "cleaning #{build_dir} before compile"
      rm_rf build_dir
      mkdir_p build_dir
    else
      puts "skipping cleaning #{build_dir}"
    end

    default_class_path = ["javalib/mirah-parser.jar", build_dir, "javalib/asm-5.jar", *classpath].join(File::PATH_SEPARATOR)

    # Compile Mirah sources
    runjava('-Xmx512m',
            '-jar',
            old_jar,
            '-d', build_dir,
            '-classpath', default_class_path,
            '--jvm', build_version,
            *mirah_srcs)
end

bootstrap_mirah_from('javalib/mirahc-prev.jar', 'dist/mirahc.jar')
bootstrap_mirah_from('dist/mirahc.jar', 'dist/mirahc2.jar')
bootstrap_mirah_from('dist/mirahc2.jar', 'dist/mirahc3.jar')

# Parser tasks!
#task :build_parser => ['dist/mirah-parser.jar']




# TODO maybe add these back at some point?
#task :doc => 'build/mirahparser/lang/ast/Node.java' do
#  ant.javadoc :sourcepath => 'build', :destdir => 'doc'
#end

mirah_parser_gen_src = 'build/mirah-parser-gen/mirahparser/impl/Mirah.mirah'
mirah_parser_build_dir = "build/mirah-parser"
parser_node_meta_class = "#{mirah_parser_build_dir}/org/mirahparser/ast/NodeMeta.class"
parser_node_java_gen_src = "#{mirah_parser_build_dir}-gen/mirahparser/lang/ast/Node.java"
parser_node_class = "#{mirah_parser_build_dir}/mirahparser/lang/ast/Node.class"
parser_meta_src = 'mirah-parser/src/org/mirah/ast/meta.mirah'
prev_jar = 'javalib/mirahc-prev.jar'
directory "#{mirah_parser_build_dir}/mirah-parser/mirahparser/impl"


file 'build/mirah-parser.jar' => ["#{mirah_parser_build_dir}/mirahparser/lang/ast/Node.class",
                                  "#{mirah_parser_build_dir}/mirahparser/impl/MirahParser.class",
                                  "#{mirah_parser_build_dir}/mirahparser/impl/MirahLexer.class"] do
  ant.jarjar 'jarfile' => 'build/mirah-parser.jar' do
    fileset 'dir' => mirah_parser_build_dir, 'includes' => 'mirahparser/impl/*.class'
    fileset 'dir' => mirah_parser_build_dir, 'includes' => 'mirahparser/lang/ast/*.class'
    fileset 'dir' => mirah_parser_build_dir, 'includes' => 'org/mirahparser/ast/*.class'
    zipfileset 'src' => 'mirah-parser/javalib/mmeta-runtime.jar'
    _element 'rule', 'pattern'=>'mmeta.**', 'result'=>'org.mirahparser.mmeta.@1'
    manifest do
      attribute 'name'=>"Main-Class", 'value'=>"mirahparser.impl.MirahParser"
    end
  end
end

file 'dist/mirah-parser.jar' => 'build/mirah-parser.jar' do
  # Mirahc picks up the built in classes instead of our versions.
  # So we compile in a different package and then jarjar them to the correct
  # one.
  ant.jarjar 'jarfile' => 'dist/mirah-parser.jar' do
    zipfileset 'src' => 'build/mirah-parser.jar'
    _element 'rule', 'pattern'=>'mirahparser.**', 'result'=>'mirah.@1'
    _element 'rule', 'pattern'=>'org.mirahparser.**', 'result'=>'org.mirah.@1'
    manifest do
      attribute 'name'=>"Main-Class", 'value'=>"mirah.impl.MirahParser"
    end
  end
end



file "#{mirah_parser_build_dir}/mirahparser/impl/MirahParser.class" => [
    prev_jar,
    mirah_parser_gen_src,
    parser_node_meta_class,
    "#{mirah_parser_build_dir}/mirahparser/impl/MirahLexer.class",
    #"#{mirah_parser_build_dir}/mirahparser/impl/Tokens.class",
  ] do
  compile_mirah_with_jar prev_jar,
                         mirah_parser_build_dir,
                         [mirah_parser_gen_src],
                         [mirah_parser_build_dir,
                          'mirah-parser/javalib/mmeta-runtime.jar',
                           prev_jar],
                          clean=false
end

file parser_node_meta_class => parser_meta_src do
  compile_mirah_with_jar prev_jar,
                         mirah_parser_build_dir,
                         [parser_meta_src],
                         [mirah_parser_build_dir, prev_jar],
                         clean=false
  #mirahc(parser_meta_src,
  #       :dest => mirah_parser_build_dir
  #       #:options => ['-V']
  #      )
end
parser_ast_srcs = Dir['mirah-parser/src/mirah/lang/ast/*.mirah'].sort
file parser_node_class =>
    [prev_jar, parser_node_meta_class] + parser_ast_srcs do
        compile_mirah_with_jar prev_jar,
                         mirah_parser_build_dir,
                         parser_ast_srcs,
                         [mirah_parser_build_dir,
                          'mirah-parser/javalib/mmeta-runtime.jar', prev_jar],
                         clean = false
end

file parser_node_java_gen_src =>
    [parser_node_meta_class] + parser_ast_srcs do
#TODO. --java is nolonger supported.
#        compile_mirah_with_jar prev_jar,
#                         mirah_parser_build_dir,
#                         parser_ast_srcs,
#                         [mirah_parser_build_dir,
#                          'mirah-parser/javalib/mmeta-runtime.jar']

      mirahc('.',
             :dir => 'mirah-parser/src/mirah/lang/ast',
             :dest => 'build',
             :classpath => ['build'],
             :options => ['--java'])
end

parser_java_impl_src = Dir['mirah-parser/src/mirahparser/impl/*.java'].sort
parser_lexer_class = "#{mirah_parser_build_dir}/mirahparser/impl/MirahLexer.class"
file parser_lexer_class => parser_java_impl_src do
  ant.javac 'srcDir' => 'mirah-parser/src',
      'destDir' => mirah_parser_build_dir,
      'source' => '1.6',
      'target' => '1.6',
      'debug' => true do
    include 'name' => 'mirahparser/impl/Tokens.java'
    include 'name' => 'mirahparser/impl/MirahLexer.java'
    classpath 'path' => "#{mirah_parser_build_dir}:mirah-parser/javalib/mmeta-runtime.jar"
  end
end

file mirah_parser_gen_src => 'mirah-parser/src/mirahparser/impl/Mirah.mmeta' do
  ant.mkdir 'dir' => "#{mirah_parser_build_dir}-gen/mirahparser/impl"
  runjava '-jar', 'mirah-parser/javalib/mmeta.jar',
          '--tpl', 'node=mirah-parser/src/mirahparser/impl/node.xtm',
          'mirah-parser/src/mirahparser/impl/Mirah.mmeta',
          mirah_parser_gen_src
end


def build_version
  # mirahc needs to be 1.7 or lower
  java_version = java.lang.System.getProperty('java.specification.version')
  if java_version.to_f > 1.7
    '1.7'
  else
    java_version
  end
end

def runjava(*args)
  sh 'java',*args
  unless $?.success?
    exit $?.exitstatus
  end
end
