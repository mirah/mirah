Mirah
================

[![Build Status](https://secure.travis-ci.org/mirah/mirah.png)](http://travis-ci.org/mirah/mirah)

* http://groups.google.com/group/mirah
* http://github.com/mirah/mirah/issues


DESCRIPTION
-----------------

Mirah is a customizable programming language featuring static types,
local type inference and a heavily Ruby-inspired syntax. Mirah
currently includes a typer/compiler backend for the JVM which can
output JVM bytecode.


FEATURES
-----------------

* Ruby-like syntax
* Compiles to .class
* Fast as Java
* No runtime library


SYNOPSIS
-----------------

    mirah <script.mirah>
    mirah -e "inline script"
    mirahc <script.mirah>
    mirahc -e "inline script" # produces DashE.class


REQUIREMENTS
-----------------

* Java 1.7 or higher.


INSTALL
-----------------

### RUBY

If your gem and rake are not from JRuby, prefix the commands with `jruby -S`

    $ gem install mirah

### JAR

Mirah is distributed as a jar through maven central. You can download the latest jar from
[maven.org](http://search.maven.org/#search%7Cga%7C1%7Cg%3A%22org.mirah%22%20a%3A%22mirah%22).

### ZIP

You can also install Mirah from a zip file. Download the latest stable
release from https://github.com/mirah/mirah/releases.
Extract it, and add `bin` to your `$PATH` to be able to use `mirah`, `mirahc`, etc.

### SOURCE

Setup building locally and installing from source, you'll need jruby 1.7.12 or
higher. Then just follow these commands.

#### To get the repository setup locally run the following:

    $ git clone http://github.com/mirah/mirah.git
    $ cd mirah
    $ bundle install

#### To install mirah as a gem from source:

    $ rake gem
    $ gem install pkg/mirah-*.gem

#### To create the mirahc jar:

    $ rake dist/mirahc.jar

This will create a mirahc.jar file in dist that you can run to compile mirah source files.
