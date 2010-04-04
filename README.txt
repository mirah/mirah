= duby

* http://kenai.com/projects/duby

== DESCRIPTION:

Duby is a customizable programming language featuring static types,
local type inference and a heavily Ruby-inspired syntax. Duby
currently includes a typer/compiler backend for the JVM which can
output either JVM bytecode or Java source files.

== FEATURES/PROBLEMS:

* Ruby syntax
* Compiles to .class or .java
* Fast as Java

== SYNOPSIS:

duby <script.duby>
duby -e "inline script"
dubyc <script.duby>
dubyc -e "inline script" # produces DashE.class
dubyc -java <script.duby>
dubyc -java -e "inline script" # produces DashE.java

== REQUIREMENTS:

* JRuby 1.5.0 or higher.
* BiteScript 0.0.5 or higher

== INSTALL:

If your "gem" command is the one from JRuby:

* gem install duby

Otherwise:

* jruby -S gem install duby

Only JRuby is supported at this time.

== For Java tools:

To build the Duby jars from source you should have a checkout of both jruby and
bitescript in Duby's parent directory. Run "ant jar-complete" in jruby, then in
the duby directory "../jruby/bin/jruby -S rake jar" to build the Duby jar. Use
"jar:complete" instead to produce a free-standing jar file with JRuby and the
JRubyParser libraries included.
