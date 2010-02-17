require 'rake'
require 'rake/testtask'
require 'java'

task :default => :test

Rake::TestTask.new :test do |t|
  t.libs << "lib"
  # This is hacky, I know
  t.libs.concat Dir["../bitescript*/lib"]
  t.test_files = FileList["test/**/*.rb"]
  java.lang.System.set_property("jruby.duby.enabled", "true")
end
