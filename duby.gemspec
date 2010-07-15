# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = 'duby'
  s.version = "0.0.4"
  s.authors = ["Charles Oliver Nutter", "Ryan Brown"]
  s.date = Time.now.strftime("YYYY-MM-DD")
  s.description = %q{Duby is now Mirah. Please install the Mirah gem instead.}
  s.email = ["headius@headius.com", "ribrdb@google.com"]
  s.executables = ["duby", "dubyc", "dubyp"]
  s.files = []
  s.homepage = %q{http://www.mirah.org/}
  s.platform = "java"
  s.summary = %q{Backwards compatibility wrapper for the `mirah` gem}
  s.add_dependency("mirah", ">= 0.0.4")
end
