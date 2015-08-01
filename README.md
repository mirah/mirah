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

* JRuby 1.6.0 or higher.
* BiteScript 0.0.8 or higher

INSTALL
-----------------

&nbsp; RUBY

&nbsp;&nbsp;&nbsp;If your gem and rake are not from from JRuby, prefix the commands with `jruby -S`

    $ gem install mirah

&nbsp; ZIP


&nbsp;&nbsp;&nbsp;You can also install Mirah from a zip file. Download the latest stable release from https://github.com/mirah/mirah/downloads.
&nbsp;&nbsp;&nbsp;Extract it, and add `bin` to your `$PATH` to be able to use `mirah`, `mirahc`, etc.

&nbsp; SOURCE

&nbsp;&nbsp;&nbsp;To build and install from source, you'll need jruby 1.7.0 or higher. Then just follow these commands:

    $ git clone http://github.com/mirah/mirah.git
    $ cd mirah
    $ bundle install
    $ rake gem
    $ gem install pkg/mirah-*.gem

&nbsp; For Java tools

&nbsp;&nbsp;&nbsp;To build the Mirah jar from source run `rake jar` in the mirah directory.
