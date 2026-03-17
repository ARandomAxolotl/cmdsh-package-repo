@echo off
setlocal enabledelayedexpansion

set "force=0"
set "nopreserve=0"
set "target="

:parse_args
if "%~1"=="" goto :execute
set "arg=%~1"

:: Check for flags
if "!arg!"=="-rf" (set "force=1" & shift & goto :parse_args)
if "!arg!"=="--no-preserve-root" (set "nopreserve=1" & shift & goto :parse_args)

:: If it's not a flag, it must be the target
set "target=%~1"
shift
goto :parse_args

:execute
if "!target!"=="" (
    echo Usage: rm [-rf] [--no-preserve-root] ^<target^>
    exit /b 1
)

:: Safety Check
if "!target!"=="C:\" if !nopreserve! neq 1 (
    echo rm: it is dangerous to operate recursively on 'C:/'
    echo use --no-preserve-root to override
    exit /b 1
)

:: Deletion Logic
if !force! equ 1 (
    if exist "!target!\" ( rd /s /q "!target!" ) else ( del /f /q "!target!" )
) else (
    if exist "!target!\" ( rd "!target!" ) else ( del "!target!" )
)

exit /b %errorlevel%