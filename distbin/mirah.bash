#!/bin/bash
# -----------------------------------------------------------------------------
# mirah.bash - Start Script for Mirah runner
# -----------------------------------------------------------------------------

cygwin=false

# ----- Identify OS we are running under --------------------------------------
case "`uname`" in
  CYGWIN*) cygwin=true;;
  Darwin) darwin=true;;
esac

## resolve links - $0 may be a link to  home
PRG=$0
progname=`basename "$0"`

while [ -h "$PRG" ] ; do
  ls=`ls -ld "$PRG"`
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '.*/.*' > /dev/null; then
    if expr "$link" : '/' > /dev/null; then
      PRG="$link"
    else
      PRG="`dirname ${PRG}`/${link}"
    fi
  else
    PRG="`dirname $PRG`/$link"
  fi
done

MIRAH_HOME_1=`dirname "$PRG"`           # the ./bin dir
if [ "$MIRAH_HOME_1" = '.' ] ; then
  cwd=`pwd`
  MIRAH_HOME=`dirname $cwd`
else
  MIRAH_HOME=`dirname "$MIRAH_HOME_1"`  # the . dir
fi

if [ -z "$JAVACMD" ] ; then
  if [ -z "$JAVA_HOME" ] ; then
    JAVACMD='java'
  else
    if $cygwin; then
      JAVACMD="`cygpath -u "$JAVA_HOME"`/bin/java"
    else
      JAVACMD="$JAVA_HOME/bin/java"
    fi
  fi
fi

if [ -z "$JAVA_MEM" ] ; then
  JAVA_MEM=-Xmx500m
fi

if [ -z "$JAVA_STACK" ] ; then
  JAVA_STACK=-Xss2048k
fi

# process JAVA_OPTS
unset JAVA_OPTS_TEMP
JAVA_OPTS_TEMP=""
for opt in ${JAVA_OPTS[@]}; do
  case $opt in
    -server)
      JAVA_VM="-server";;
    -Xmx*)
      JAVA_MEM=$opt;;
    -Xms*)
      JAVA_MEM_MIN=$opt;;
    -Xss*)
      JAVA_STACK=$opt;;
    *)
      JAVA_OPTS_TEMP="${JAVA_OPTS_TEMP} $opt";;
  esac
done

JAVA_OPTS=$JAVA_OPTS_TEMP


# ----- Set Up The Boot Classpath -------------------------------------------

CP_DELIMITER=":"

# add main mirah jar to the bootclasspath
MIRAH_CP="$MIRAH_HOME"/lib/mirah-complete.jar

if $cygwin; then
    MIRAH_CP=`cygpath -p -w "$MIRAH_CP"`
fi

# ----- Execute The Requested Command -----------------------------------------

declare -a mirah_args
set -- $MIRAH_OPTS "$@"
while [ $# -gt 0 ]
do
    case "$1" in
     # Match switches that take an argument
     -c|--classpath|--cd|-d|--dir|-e|-I|--jvm|-p|--plugin|-e|-I|-S) mirah_args=("${mirah_args[@]}" "$1" "$2"); shift ;;
     # Other opts go to mirah
     -*) mirah_args=("${mirah_args[@]}" "$1") ;;
     # Abort processing on first non-opt arg
     *) break ;;
    esac
    shift
done

# Append the rest of the arguments
mirah_args=("${mirah_args[@]}" "$@")

# Put the mirah_args back into the position arguments $1, $2 etc
set -- "${mirah_args[@]}"

JAVA_OPTS="$JAVA_OPTS $JAVA_MEM $JAVA_MEM_MIN $JAVA_STACK"

if $cygwin; then
  MIRAH_HOME=`cygpath --mixed "$MIRAH_HOME"`

  if [[ ( "${1:0:1}" = "/" ) && ( ( -f "$1" ) || ( -d "$1" )) ]]; then
    win_arg=`cygpath -w "$1"`
    shift
    win_args=("$win_arg" "$@")
    set -- "${win_args[@]}"
  fi
fi

if $cygwin; then
  # exec does not work correctly with cygwin bash
  "$JAVACMD" $JAVA_OPTS -jar "$MIRAH_CP" run "$@"

  exit $?
else
  exec "$JAVACMD" $JAVA_OPTS -jar "$MIRAH_CP" run "$@"
fi

# Be careful adding code down here, you might override the exit
# status of the mirah invocation.
