@echo off
setlocal enabledelayedexpansion

:: Define the highlight color (Bright Red) and Reset
set "RED=[91m"
set "W=[0m"

set "pattern=%~1"
set "file=%~2"

if "%pattern%"=="" (
    echo Usage: grep ^<pattern^> [file]
    exit /b 1
)

:: Run the search and use a loop to highlight matches
if "%file%"=="" (
    for /f "delims=" %%A in ('findstr /i /r /c:"%pattern%"') do (
        set "line=%%A"
        :: Replace the pattern with [RED]pattern[WHITE]
        echo !line:%pattern%=%RED%%pattern%%W%!
    )
) else (
    if not exist "%file%" (
        echo grep: %file%: No such file or directory
        exit /b 1
    )
    for /f "delims=" %%A in ('findstr /i /r /c:"%pattern%" "%file%"') do (
        set "line=%%A"
        echo !line:%pattern%=%RED%%pattern%%W%!
    )
)
exit /b 0