require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

Rake::TestTask.new do |t|
  t.libs << "lib"
  t.libs << "../jvmscript/lib"
  t.test_files = FileList["test/**/*.rb"]
end