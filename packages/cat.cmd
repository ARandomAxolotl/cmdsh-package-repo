@echo off
setlocal enabledelayedexpansion

:: --- Configuration ---
:: Get the true ESC character for colors
for /f "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"

set "showLines=false"
set "targetFile="

:: --- Argument Parser ---
:parse_args
if "%~1"=="" goto :execute
if /i "%~1"=="-n" (
    set "showLines=true"
    shift
    goto :parse_args
)
set "targetFile=%~1"
shift
goto :parse_args

:: --- Execution ---
:execute
if "!targetFile!"=="" (
    :: FIX: Dùng ^^ để Batch không "ăn" mất ký tự của regex
    findstr "^^"
    goto :eof
)

if not exist "!targetFile!" (
    echo %ESC%[31mcat: !targetFile!: No such file or directory%ESC%[0m
    exit /b 1
)

:: Read the file and process colors / line numbers
set "lineNum=0"
:: FIX: Nhân đôi ^^ bên trong backticks để bảo toàn ký tự ^ cho findstr
for /f "usebackq tokens=1,* delims=:" %%A in (`findstr /n "^^" "!targetFile!"`) do (
    set /a lineNum+=1
    set "line=%%B"
    
    if defined line (
        :: Miniature Markdown Color Parser
        set "line=!line:{red}=%ESC%[31m!"
        set "line=!line:{green}=%ESC%[32m!"
        set "line=!line:{yellow}=%ESC%[33m!"
        set "line=!line:{blue}=%ESC%[34m!"
        set "line=!line:{magenta}=%ESC%[35m!"
        set "line=!line:{cyan}=%ESC%[36m!"
        set "line=!line:{gray}=%ESC%[90m!"
        set "line=!line:{reset}=%ESC%[0m!"
        
        :: Print to screen (with or without line numbers)
        if "!showLines!"=="true" (
            echo %ESC%[90m!lineNum!%ESC%[0m !line!%ESC%[0m
        ) else (
            echo !line!%ESC%[0m
        )
    ) else (
        :: Handle empty lines
        if "!showLines!"=="true" (
            echo %ESC%[90m!lineNum!%ESC%[0m
        ) else (
            echo.
        )
    )
)
exit /b 0