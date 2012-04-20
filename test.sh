#!/bin/bash
# For some reason the builtins have to be on the JVM classpath to load properly.
# This script runs rake with the right classpath
if [ ! -e javalib/mirah-builtins.jar ]; then
    jruby -S rake bootstrap
fi
CLASSPATH=javalib/mirah-parser.jar:javalib/mirah-bootstrap.jar:javalib/mirah-builtins.jar
if [ $# = 0 ]; then
    EXTRA_ARGS=test
fi
exec jruby -S rake "$@" $EXTRA_ARGS