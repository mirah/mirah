# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = 'duby'
  s.version = "0.0.3.dev"
  s.authors = ["Charles Oliver Nutter", "Ryan Brown"]
  s.date = Time.now.strftime("YYYY-MM-DD")
  s.description = %q{Duby is a customizable programming language featuring static types,
local type inference and a heavily Ruby-inspired syntax. Duby
currently includes a typer/compiler backend for the JVM which can
output either JVM bytecode or Java source files.}
  s.email = ["headius@headius.com", "ribrdb@google.com"]
  s.executables = ["duby", "dubyc", "dubyp"]
  s.extra_rdoc_files = ["History.txt", "README.txt"]
  s.files = Dir["{bin,lib,test,examples,javalib}/**/*"] + Dir["{*.txt,Rakefile}"]
  s.homepage = %q{http://kenai.com/projects/duby}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{duby}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Duby is a customizable programming language featuring static types, local type inference and a heavily Ruby-inspired syntax}
  s.test_files = Dir["test/**/test*.rb"]
  s.platform = "java"
  s.add_dependency("bitescript", ">= 0.0.5")
end
