@echo off

if "%1" == "" (
	echo Input a file
	exit /b
)
set "outputfile=%1"

if not exist %~dp0.cache mkdir %~dp0.cache
type nul > "%~dp0.cache\temp.txt"

type "%outputfile%" > "%~dp0.cache\temp.txt"
rem Undo!!

:loop
:: 1. Turn OFF delayed expansion while we take user input.
:: This ensures that '!' characters are safely read as raw text.
setlocal disabledelayedexpansion
set "i="
set /p "i="

:: 2. Temporarily turn it ON just to safely evaluate the string.
setlocal enabledelayedexpansion
if "!i!" == "^!exit" (
	del %~dp0.cache\temp.txt
	exit /b 0 
) else if "!i!" == "^!cat" (
	echo -----------
	call cat "%outputfile%"
	echo -----------
	endlocal & endlocal
	goto loop
) else if "!i!" == "^!cat2" (
	echo -----------
	call cat -n "%outputfile%"
	echo -----------
	endlocal & endlocal
	goto loop
) else if "!i!" == "^!undo" (
	for /F %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
	set "RED=!ESC![31m"
	set "RESET=!ESC![0m
	
	echo !RED!Undo-ed!RESET!
	type "%~dp0.cache\temp.txt" > "%outputfile%"
	goto loop
) else if "!i!" == "^!clear" (
	for /F %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
	set "RED=!ESC![31m"
	set "RESET=!ESC![0m"
	
	:: Output the red text and reset it immediately without dangling '!' marks
	echo !RED!Cleared "%outputfile%"!RESET!
	
	:: This wipes the file completely empty (0 bytes) with no trailing newline
	type nul > "%outputfile%"
	endlocal & endlocal
	goto loop
)

:: 3. Tunnel the exact raw string out of the inner local environment
for /f "delims=" %%G in ("!i!") do (
	endlocal
	set "raw_i=%%G"
)

:: 4. Write it safely using the disabled expansion state
if "%raw_i%" == "" (
	echo.>> "%outputfile%"
) else (
	setlocal enabledelayedexpansion
	echo !raw_i!>> "%outputfile%"
	endlocal
)

endlocal
goto loop