@echo off

if "%~1" == "" (
	echo Input a file
	exit /b
)

set "outputfile=%~1"
set "tmpfile=%RANDOM%%RANDOM%_%outputfile%"

copy "%outputfile%" "%tmpfile%" >nul

:loop
:: setlocal Disabledelayedexpandsion
set "i="
set /p "i="

if "%i%"=="a" goto :append
:: append
if "%i%"=="w" goto :write
:: write, yes
if "%i%"=="e" exit /b 
if "%i%"=="q" exit /b
:: quit
if "%i%"=="r" goto :readfile
:: read existfile
if "%i%"=="d" type nul>"%tmpfile%"
:: clear tmpbuffer

echo ?

goto :loop


:append
:: setlocal disabledelayedexpandsion
set "i="
set /p "i=(append) : "
if "%i%"=="." goto :loop
echo %i%>>"%tmpfile%"
goto :append

:write
type %tmpfile% > %outputfile%
goto :loop

:readfile
if exist "%outputfile%" (
  type "%outputfile%"
) else (
  echo File '%outputfile%' not saved/exist yet!
  echo Press 'w' to write!
)
goto :loop

