= mirah

* http://groups.google.com/group/mirah
* http://github.com/mirah/mirah/issues

== DESCRIPTION:

Mirah is a customizable programming language featuring static types,
local type inference and a heavily Ruby-inspired syntax. Mirah
currently includes a typer/compiler backend for the JVM which can
output either JVM bytecode or Java source files.

== FEATURES:

* Ruby-like syntax
* Compiles to .class or .java
* Fast as Java
* No runtime library

== SYNOPSIS:

mirah <script.mirah>
mirah -e "inline script"
mirahc <script.mirah>
mirahc -e "inline script" # produces DashE.class
mirahc --java <script.mirah>
mirahc --java -e "inline script" # produces DashE.java

== REQUIREMENTS:

* JRuby 1.6.0 or higher.
* BiteScript 0.0.8 or higher

== INSTALL:

=== RUBY:
If your gem and rake are not from from JRuby, prefix the commands with jruby -S

$ gem install mirah

=== ZIP:

You can also install Mirah from a zip file. Download the latest stable
release from https://github.com/mirah/mirah/downloads. 
Extract it, and add `bin` to your `$PATH` to be able to use `mirah`, `mirahc`, etc.

=== SOURCE:

To build and install from source,

$ git clone http://github.com/mirah/mirah.git
$ cd mirah
$ bundle install
$ rake gem
$ gem install pkg/mirah-*.gem

== For Java tools:

To build the Mirah jar from source run "rake jar" in the mirah directory.
