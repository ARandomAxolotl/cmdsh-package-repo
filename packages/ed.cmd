@echo off

if "%1" == "" (
	echo Input a file
	exit /b
)
set "outputfile=%1"

:loop
:: 1. Turn OFF delayed expansion while we take user input.
:: This ensures that '!' characters are safely read as raw text[cite: 7].
setlocal disabledelayedexpansion
set "i="
set /p "i="

:: 2. Temporarily turn it ON just to safely evaluate the string.
setlocal enabledelayedexpansion
if "!i!" == "^!exit" (
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
) else if "!i!" == "^!clear" (
	echo Cleared file "%outputfile%"
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