require 'rake'
require 'rake/testtask'
require 'java'
$: << './lib'
require 'duby'
require 'jruby/compiler'
require 'ant'

task :default => :test

Rake::TestTask.new :test do |t|
  t.libs << "lib"
  # This is hacky, I know
  t.libs.concat Dir["../bitescript*/lib"]
  t.test_files = FileList["test/**/*.rb"]
  java.lang.System.set_property("jruby.duby.enabled", "true")
end

task :default => :jar

task :bootstrap do
  mkdir 'dist'
  ant.jar :jarfile => 'dist/duby.jar' do
    fileset :dir => 'lib'
    fileset :dir => '.', :includes => 'bin/*'
    fileset :dir => '../bitescript/lib'
    fileset :dir => '../jruby/lib/ruby/1.8'
  end
end

task :clean do
  ant.delete :quiet => true, :dir => 'build'
  ant.delete :quiet => true, :dir => 'dist'
end

task :compile do
  mkdir_p 'build'

  # build the Ruby sources
  puts "Compiling Ruby sources"
  JRuby::Compiler.compile_argv([
    '-t', 'build',
    '--javac',
    'src/org/jruby/duby/duby_command.rb'
  ])
  
  # build the Duby sources
  puts "Compiling Duby sources"
  Dir.chdir 'src' do
    Duby.compile(
      '-c', '../jruby/lib/jruby-complete.jar:javalib/JRubyParser.jar:dist/duby.jar:build:/usr/share/ant/lib/ant.jar',
      '-d', '../build',
      'org/jruby/duby')
  end
end

task :jar => :compile do
  mkdir_p 'dist'
  ant.jar :jarfile => 'dist/duby.jar' do
    fileset :dir => 'lib'
    fileset :dir => 'build'
    fileset :dir => '.', :includes => 'bin/*'
    fileset :dir => '../bitescript/lib'
    manifest do
      attribute :name => 'Main-Class', :value => 'org.jruby.duby.DubyCommand'
    end
  end
end

namespace :jar do
  task :complete => :jar do
    mkdir_p 'dist'
    ant.jar :jarfile => 'dist/duby-complete.jar' do
      zipfileset :src => 'dist/duby.jar'
      zipfileset :src => '../jruby/lib/jruby-complete.jar'
      zipfileset :src => 'javalib/JRubyParser.jar'
      manifest do
        attribute :name => 'Main-Class', :value => 'org.jruby.duby.DubyCommand'
      end
    end
  end
end