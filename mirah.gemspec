# -*- encoding: utf-8 -*-
$: << './lib'
require 'mirah/version'

files = Dir["{bin,lib,test,examples}/**/*"] \
        + ['dist/mirahc.jar']               \
        + Dir["{*.md,*.txt,Rakefile}"]      \
        - Dir["{examples/wiki/**/*}"]

mirahc_jar = 'dist/mirahc.jar'
if $PROGRAM_NAME.match(/gem$/) && !files.include?(mirahc_jar)
  $stderr.puts "-"*80
  $stderr.puts "ERROR: Can't build gem: missing generated file #{mirahc_jar}"
  $stderr.puts "To generate the jars and build the gem, use"
  $stderr.puts "   $ rake gem"
  $stderr.puts "-"*80
  exit 1
end


Gem::Specification.new do |s|
  s.name = 'mirah'
  s.version = Mirah::VERSION
  s.license = 'Apache-2.0'
  s.authors = ["Charles Oliver Nutter", "Ryan Brown", "Nick Howard"]
  s.email = ["headius@headius.com", "ribrdb@google.com", "ndh@baroquebobcat.com"]
  s.date =  Time.now.strftime("%Y-%m-%d")
  s.description = %q{Mirah is a customizable programming language featuring static types,
local type inference and a heavily Ruby-inspired syntax. Mirah
currently includes a typer/compiler backend for the JVM which can
output either JVM bytecode or Java source files.}
  s.executables = ["mirah", "mirahc"]
  s.extra_rdoc_files = ["History.txt", "README.md"]
  s.files = files.reject {|file| file =~ /jruby-complete.jar|jsr292-mock.jar/}
  s.homepage = %q{http://www.mirah.org/}
  s.rdoc_options = ["--main", "README.md"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{mirah}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Mirah is a customizable programming language featuring static types, local type inference and a heavily Ruby-inspired syntax}
  s.test_files = Dir["test/**/test*.rb"]
  s.platform = "java"
end
