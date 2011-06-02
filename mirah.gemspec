# -*- encoding: utf-8 -*-
$: << './lib'
require 'mirah/version'

Gem::Specification.new do |s|
  s.name = 'mirah'
  s.version = Mirah::VERSION
  s.authors = ["Charles Oliver Nutter", "Ryan Brown"]
  s.date =  Time.now.strftime("%Y-%m-%d")
  s.description = %q{Mirah is a customizable programming language featuring static types,
local type inference and a heavily Ruby-inspired syntax. Mirah
currently includes a typer/compiler backend for the JVM which can
output either JVM bytecode or Java source files.}
  s.email = ["headius@headius.com", "ribrdb@google.com"]
  s.executables = ["mirah", "mirahc", "mirahp"]
  s.extra_rdoc_files = ["History.txt", "README.txt"]
  files = Dir["{bin,lib,test,examples,javalib}/**/*"] + Dir["{*.txt,Rakefile}"] - Dir["{examples/wiki/**/*}"]
  s.files = files.reject {|file| file =~ /jruby-complete.jar|jsr292-mock.jar/}
  s.homepage = %q{http://www.mirah.org/}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{mirah}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Mirah is a customizable programming language featuring static types, local type inference and a heavily Ruby-inspired syntax}
  s.test_files = Dir["test/**/test*.rb"]
  s.platform = "java"
  s.add_dependency("bitescript", ">= 0.0.8")
end
