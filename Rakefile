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

require 'ant'
require 'rake/testtask'

task :default => :build_parser

task :clean do
  ant.delete 'quiet' => true, 'dir' => 'build'
  ant.delete 'quiet' => true, 'dir' => 'dist'
end


file_create 'javalib/mirahc.jar' do
  require 'open-uri'
  url = 'https://search.maven.org/remotecontent?filepath=org/mirah/mirah/0.1.3/mirah-0.1.3.jar'

  puts "Downloading mirahc.jar from #{url}"

  open(url, 'rb') do |src|
    open('javalib/mirahc.jar', 'wb') do |dest|
      dest.write(src.read)
    end
  end
end


task :build_parser => ['javalib/mirahc.jar', 'dist/mirah-parser.jar']
ant.taskdef 'name' => 'jarjar', 'classpath' => 'javalib/jarjar-1.1.jar', 'classname'=>"com.tonicsystems.jarjar.JarJarTask"

def mirahc(path, options)
  args = options[:options] || []

  if options[:classpath]
    options[:classpath] << 'javalib/mirahc.jar'
  else 
    options[:classpath] = ['javalib/mirahc.jar']
  end
  if options[:classpath]
    cp = options[:classpath].map {|p| File.expand_path(p)}.join(File::PATH_SEPARATOR)
    args << '--classpath' << cp << '--jvm' << '1.7'
  end
  args << '-d' << File.expand_path(options[:dest])
  jarfile = File.expand_path('javalib/mirahc.jar')

  dir = options[:dir] || '.'
  filename = File.join(dir, path)
  filename.sub! /\.$/, '*'
  args += Dir[filename].sort
  runjava(jarfile, *args)
end

file 'build/mirah-parser.jar' => ['build/mirahparser/lang/ast/Node.class',
                                  'build/mirahparser/impl/MirahParser.class',
                                  'build/mirahparser/impl/MirahLexer.class'] do
  ant.jarjar 'jarfile' => 'build/mirah-parser.jar' do
    fileset 'dir' => 'build', 'includes' => 'mirahparser/impl/*.class'
    fileset 'dir' => 'build', 'includes' => 'mirahparser/lang/ast/*.class'
    fileset 'dir' => 'build', 'includes' => 'org/mirahparser/ast/*.class'
    zipfileset 'src' => 'javalib/mmeta-runtime.jar'
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

file 'build/mirahparser/impl/MirahParser.class' => [
    'build/mirahparser/impl/Mirah.mirah',
    'build/org/mirahparser/ast/NodeMeta.class',
    'build/mirahparser/impl/MirahLexer.class',
  ] do
  mirahc('mirahparser/impl/Mirah.mirah',
         :dir => 'build',
         :dest => 'build',
         :classpath => ['build', 'javalib/mmeta-runtime.jar'])
end

file 'build/org/mirahparser/ast/NodeMeta.class' => 'src/org/mirah/ast/meta.mirah' do
  mirahc('src/org/mirah/ast/meta.mirah',
         :dest => 'build'
         #:options => ['-V']
         )
end

file 'build/mirahparser/lang/ast/Node.class' =>
    ['build/org/mirahparser/ast/NodeMeta.class'] + Dir['src/mirah/lang/ast/*.mirah'].sort do
      mirahc('.',
             :dir => 'src/mirah/lang/ast',
             :dest => 'build',
             :classpath => ['build'])
end

file 'build/mirahparser/lang/ast/Node.java' =>
    ['build/org/mirahparser/ast/NodeMeta.class'] + Dir['src/mirah/lang/ast/*.mirah'].sort do
      mirahc('.',
             :dir => 'src/mirah/lang/ast',
             :dest => 'build',
             :classpath => ['build'],
             :options => ['--java'])
end

file 'build/mirahparser/impl/MirahLexer.class' => Dir['src/mirahparser/impl/*.java'].sort do
  ant.javac 'srcDir' => 'src',
      'destDir' => 'build',
      'source' => '1.6',
      'target' => '1.6',
      'debug' => true do
    include 'name' => 'mirahparser/impl/Tokens.java'
    include 'name' => 'mirahparser/impl/MirahLexer.java'
    classpath 'path' => 'build:javalib/mmeta-runtime.jar'
  end
end

file 'build/mirahparser/impl/Mirah.mirah' => 'src/mirahparser/impl/Mirah.mmeta' do
  ant.mkdir 'dir' => 'build/mirahparser/impl'
  runjava 'javalib/mmeta.jar', '--tpl', 'node=src/mirahparser/impl/node.xtm', 'src/mirahparser/impl/Mirah.mmeta', 'build/mirahparser/impl/Mirah.mirah'
end

directory 'dist'
directory 'build/mirahparser/impl'

# TODO this uses the mirah parser from the compiler, not the version we
# just built.
Rake::TestTask.new :test do |t|
  # t.libs << 'build/test'
  t.test_files = FileList['test/*.rb']
end

task :test => :build_parser

task :doc => 'build/mirahparser/lang/ast/Node.java' do
  ant.javadoc :sourcepath => 'build', :destdir => 'doc'
end

def runjava(jar, *args)
  sh 'java', '-jar', jar, *args
  unless $?.success?
    exit $?.exitstatus
  end
end