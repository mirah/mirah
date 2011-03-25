@echo off

rem ----- Restore Environment Variables ---------------------------------------

:cleanup
set CLASSPATH=%_CLASSPATH%
set _CLASSPATH=
set CP=%_CP%
set MIRAH_CP=%_MIRAH_CP%
set _CP=
set _MIRAH_CP=
set JAVA_COMMAND=%_JAVA_COMMAND%
set _LIBJARS=
set _RUNJAVA=
set _STARTJAVA=
set _JAVA_COMMAND=
set _VM_OPTS=
set _MIRAH_OPTS=
:finish
exit /b %E%
