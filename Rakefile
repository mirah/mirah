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

# load mirah rake task
if File.exist?('../duby/lib/mirah_task.rb')
  $:.unshift '../duby/lib'
elsif File.exist?('../mirah/lib/mirah_task.rb')
  $:.unshift '../mirah/lib'
end
require 'mirah_task'

task :default => :build_parser

task :clean do
  ant.delete :quiet => true, :dir => 'build'
  ant.delete :quiet => true, :dir => 'dist'
end

task :build_parser => 'dist/mirah-parser.jar'

file 'dist/mirah-parser.jar' => ['build/mirah/impl/MirahParser.class'] do
  ant.jar :destfile => 'dist/mirah-parser.jar' do
    fileset :dir => 'build', :includes => 'mirah/impl/*.class'
    zipfileset :src => 'javalib/jmeta-runtime.jar'
    manifest do
      attribute :name=>"Main-Class", :value=>"mirah.impl.MirahParser"
    end
  end
end

file 'build/mirah/impl/MirahParser.class' =>
    ['build/mirah/impl/Mirah.mirah', 'build/mirah/impl/MirahLexer.class'] do
  mirahc('build/mirah/impl/Mirah.mirah',
         :dir => 'build',
         :dest => 'build',
         :options => ['--classpath', 'dist/mmeta.jar'])
end

file 'build/mirah/impl/MirahLexer.class' do
  ant.javac :srcDir => 'src',
      :destDir => 'build',
      :debug => true do
    include :name => 'mirah/impl/Tokens.java'
    include :name => 'mirah/impl/MirahLexer.java'
    classpath :path => 'javalib/jmeta-runtime.jar'
  end
end

file 'build/mirah/impl/Mirah.mirah' do
  ant.mkdir :dir => 'build/mirah/impl'
  runjava 'javalib/mmeta.jar', 'src/mirah/impl/Mirah.mmeta', 'build/mirah/impl/Mirah.mirah'
end

directory 'dist'
directory 'build/mirah/impl'

Rake::TestTask.new :test do |t|
  # t.libs << 'build/test'
  t.test_files = FileList['test/*.rb']
end

task :test => :build_parser

def runjava(jar, *args)
  options = {:failonerror => true, :fork => true}
  if jar =~ /\.jar$/
    options[:jar] = jar
  else
    options[:classname] = jar
  end
  options.merge!(args.pop) if args[-1].kind_of?(Hash)
  puts "java #{jar} " + args.join(' ')
  ant.java options do
    args.each do |value|
      arg :value => value
    end
  end
end