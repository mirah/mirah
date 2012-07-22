@echo off
rem Environment Variable Prequisites:
rem
rem   JAVA_HOME     Must point at your Java Development Kit installation.
rem

rem ----- Save Environment Variables That May Change --------------------------

set _CLASSPATH=%CLASSPATH%
set _CP=%CP%
set _MIRAH_CP=%MIRAH_CP%
set MIRAH_BAT_ERROR=0

rem ----- Verify and Set Required Environment Variables -----------------------

if not "%JAVA_HOME%" == "" goto gotJava

echo You must set JAVA_HOME to point at your JRE/JDK installation
set MIRAH_BAT_ERROR=1
exit /b 1
:gotJava

set MIRAH_HOME=%~dp0..

rem ----- Prepare Appropriate Java Execution Commands -------------------------

if not "%JAVA_COMMAND%" == "" goto gotCommand
set _JAVA_COMMAND=%JAVA_COMMAND%
set JAVA_COMMAND=java
:gotCommand

if not "%OS%" == "Windows_NT" goto noTitle
rem set _STARTJAVA=start "Mirah" "%JAVA_HOME%\bin\java"
set _STARTJAVA=%JAVA_HOME%\bin\%JAVA_COMMAND%
goto gotTitle
:noTitle
rem set _STARTJAVA=start "%JAVA_HOME%\bin\java"
set _STARTJAVA=%JAVA_HOME%\bin\%JAVA_COMMAND%
:gotTitle

rem ----- Set up the VM options
call "%~dp0_mirahvmopts" %*
set _RUNJAVA="%JAVA_HOME%\bin\java"

rem ----- Set Up The Boot Classpath ----------------------------------------

for %%i in ("%MIRAH_HOME%\lib\mirah-complete.jar") do @call :setmirahcp %%i

goto :EOF

rem setmirahcp subroutine
:setmirahcp
if not "%MIRAH_CP%" == "" goto addmirahcp
set MIRAH_CP=%*
goto :EOF

:addmirahcp
set MIRAH_CP=%MIRAH_CP%;%*
goto :EOF

rem setcp subroutine
:setcp
if not "%CP%" == "" goto add
set CP=%*
goto :EOF

:add
set CP=%CP%;%*
goto :EOF
