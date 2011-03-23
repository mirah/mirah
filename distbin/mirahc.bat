@echo off
rem ---------------------------------------------------------------------------
rem mirah.bat - Start Script for the Mirah runner
rem
rem for info on environment variables, see internal batch script _mirahvars.bat

setlocal

rem Sometimes, when mirah.bat is being invoked from another BAT file,
rem %~dp0 is incorrect and points to the current dir, not to Mirah's bin dir,
rem so we look on the PATH in such cases.
IF EXIST "%~dp0_mirahvars.bat" (set FULL_PATH=%~dp0) ELSE (set FULL_PATH=%~dp$PATH:0)

call "%FULL_PATH%_mirahvars.bat" %*

if %MIRAH_BAT_ERROR%==0 "%_STARTJAVA%" %_VM_OPTS% -jar "%MIRAH_CP%" compile %_MIRAH_OPTS%
set E=%ERRORLEVEL%

call "%FULL_PATH%_mirahcleanup"

rem 1. exit must be on the same line in order to see local %E% variable!
rem 2. we must use cmd /c in order for the exit code properly returned!
rem    See JRUBY-2094 for more details.
endlocal & cmd /d /c exit /b %E%
