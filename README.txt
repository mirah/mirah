= mirah

* http://groups.google.com/group/mirah
* http://code.google.com/p/mirah/issues/list

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
mirahc -java <script.mirah>
mirahc -java -e "inline script" # produces DashE.java

== REQUIREMENTS:

* JRuby 1.6.0 or higher.
* BiteScript 0.0.8 or higher

== INSTALL:

If your gem and rake are not from from JRuby, prefix the commands with jruby -S

$ gem install mirah

To build and install from source,

$ git clone http://github.com/mirah/mirah.git
$ cd mirah
$ bundle install
$ rake gem
$ gem install pkg/mirah-*.gem

== For Java tools:

To build the Mirah jars from source you should have a checkout of both jruby and
bitescript in Mirah's parent directory. Run "ant jar-complete" in jruby, then in
the mirah directory "../jruby/bin/jruby -S rake jar" to build the Mirah jar. Use
"jar:complete" instead to produce a free-standing jar file with JRuby and the
JRubyParser libraries included.
