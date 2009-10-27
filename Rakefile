require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'java'
require 'hoe'

$: << 'lib'
require 'duby'

task :default => :test

Rake::TestTask.new :test do |t|
  t.libs << "lib"
  t.libs << "../jvmscript/lib"
  t.test_files = FileList["test/**/*.rb"]
  java.lang.System.set_property("jruby.duby.enabled", "true")
end

# update manifest
files = []
files.concat Dir['bin/*'].to_a
files.concat Dir['lib/**/*.rb'].to_a
files.concat Dir['test/**/*.rb'].to_a
files.concat Dir['examples/**/*.duby'].to_a
files << 'History.txt'
files << 'Manifest.txt'
files << 'README.txt'
files << 'Rakefile'
files << 'javalib/JRubyParser.jar'

File.open('Manifest.txt', 'w') {|f| f.write(files.join("\n"))}

Hoe.spec 'duby' do
  developer('Charles Oliver Nutter', 'headius@headius.com')
  developer('Ryan Brown', 'ribrdb@google.com')
  extra_deps << ['bitescript', '>= 0.0.4']
end
