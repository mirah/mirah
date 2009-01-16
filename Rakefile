require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'java'

task :default => :test

Rake::TestTask.new :test do |t|
  t.libs << "lib"
  t.libs << "../jvmscript/lib"
  t.test_files = FileList["test/**/*.rb"]
  java.lang.System.set_property("jruby.duby.enabled", "true")
end