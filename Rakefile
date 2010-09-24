require 'rake'
require 'rake/testtask'
require 'java'
$: << './lib'
require 'mirah'
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

task :init do
  mkdir_p 'dist'
  mkdir_p 'build'
end

task :clean do
  ant.delete :quiet => true, :dir => 'build'
  ant.delete :quiet => true, :dir => 'dist'
end

task :compile => :init do
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
    classpath = Duby::Env.encode_paths([
        'javalib/jruby-complete.jar',
        'javalib/JRubyParser.jar',
        'build',
        '/usr/share/ant/lib/ant.jar'
      ])
    Duby.compile(
      '-c', classpath,
      '-d', '../build',
      'org/mirah',
      'duby/lang',
      'mirah'
      )
  end
end

task :jar => :compile do
  ant.jar :jarfile => 'dist/mirah.jar' do
    fileset :dir => 'lib'
    fileset :dir => 'build'
    fileset :dir => '.', :includes => 'bin/*'
    fileset :dir => '../bitescript/lib'
    manifest do
      attribute :name => 'Main-Class', :value => 'org.mirah.MirahCommand'
    end
  end
end

namespace :jar do
  task :complete => :jar do
    ant.jar :jarfile => 'dist/mirah-complete.jar' do
      zipfileset :src => 'dist/mirah.jar'
      zipfileset :src => 'javalib/jruby-complete.jar'
      zipfileset :src => 'javalib/mirah-parser.jar'
      manifest do
        attribute :name => 'Main-Class', :value => 'org.mirah.MirahCommand'
      end
    end
  end

  task :bootstrap => :compile do
    ant.jar :jarfile => 'javalib/mirah-bootstrap.jar' do
      fileset :dir => 'build'
    end
  end
end
