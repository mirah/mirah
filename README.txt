= duby

* http://kenai.com/projects/duby

== DESCRIPTION:

Duby is a customizable programming language featuring static types, local type inference and a heavily Ruby-inspired syntax. Duby currently includes a typer/compiler backend for the JVM which can output either JVM bytecode or Java source files.

== FEATURES/PROBLEMS:

* Ruby syntax
* Compiles to .class or .java
* Fast as Java

== SYNOPSIS:

duby <script.duby>
duby -e "inline script"
dubyc <script.duby>
dubyc -e "inline script" # produces dash_e.class
dubyc -java <script.duby>
dubyc -java -e "inline script" # produces dash_e.java

== REQUIREMENTS:

* JRuby 1.4RC2 or higher.
* BiteScript 0.0.4 or higher

== INSTALL:

* gem install duby
