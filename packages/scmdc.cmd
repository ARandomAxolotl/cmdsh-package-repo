@echo off
setlocal EnableExtensions DisableDelayedExpansion

:: --- Initialize Flags ---
set "SILENT=0"
set "DEBUG=0"
set "VERBOSE=0"
set "IS_BAT=0"
set "INPUT_FILE="

:: --- Parse Arguments ---
:parse_args
if "%~1"=="" goto :validate
set "arg=%~1"
if /i "!arg!"=="-s" (set "SILENT=1" & shift & goto :parse_args)
if /i "!arg!"=="-d" (set "DEBUG=1" & shift & goto :parse_args)
if /i "!arg!"=="-v" (set "VERBOSE=1" & shift & goto :parse_args)
if /i "!arg!"=="-b" (set "IS_BAT=1" & shift & goto :parse_args)

:: If not a flag, it's the input filename
if not defined INPUT_FILE (set "INPUT_FILE=%~1")
shift
goto :parse_args

:validate
if "%VERBOSE%"=="1" @echo on
if not defined INPUT_FILE (
    echo [ERROR] No input file specified.
    echo Usage: scmdc [-s] [-d] [-v] ^<filename^>
    exit /b 1
)

:: --- Setup Paths ---
pushd "%~dp0.."
set "base_dir=%CD%"
set "script_name=%INPUT_FILE%"
set "sandbox_path=%base_dir%\sandbox\%script_name%"

if not exist ".config" mkdir ".config"
if not exist "sandbox\%script_name%" mkdir "sandbox\%script_name%"

:: Security definitions
set "suspath_file=%base_dir%\.config\suspath.txt"
set "suscmd_file=%base_dir%\.config\suscmd.txt"
popd

:: --- Input/Output Setup ---
if "%IS_BAT%"=="1" (
    set "input=%INPUT_FILE%.sbat"
    set "output=%INPUT_FILE%.bat"
) else (
    set "input=%INPUT_FILE%.scmd"
    set "output=%INPUT_FILE%.cmd"
)

if not exist "%input%" (
    if "%SILENT%"=="0" echo [ERROR] File "%input%" not found.
    exit /b 1
)

set "total_lines=0"
set "temp_line=%temp%\cmdsh_line_%RANDOM%.tmp"
type nul > "%output%"

if "%SILENT%"=="0" echo [INFO] Compiling %input% to %output%...

:: --- Main Loop ---
for /f "delims=" %%L in ('findstr /n "^" "%input%"') do (
    set "raw_line=%%L"
    
    setlocal EnableDelayedExpansion
    set "line=!raw_line:*:=!"
    set /a "current_ln=!total_lines! + 1"

    :: Logging for -d (Debug)
    if "!DEBUG!"=="1" if "!SILENT!"=="0" (
        echo [DEBUG] Processing line !current_ln!: "!line!"
    ) else if "!SILENT!"=="0" (
        <nul set /p "=." :: Simple progress dots
    )

    if not defined line (
        >>"%output%" echo(
    ) else (
        :: Fix for the (echo( crash: Use a more robust redirection
        > "!temp_line!" (echo(!line!) 
        
        set "no_quotes=!line:"=!"
        set "cmd_check="
        for /f "tokens=1" %%C in ("!no_quotes!") do set "cmd_check=%%C"
        set "blocked="
        
        :: 1. Suscmd Check
        if defined cmd_check (
            findstr /i /x "!cmd_check!" "%suscmd_file%" >nul 2>&1
            if !errorlevel! equ 0 set "blocked=suscmd"
        )
        
        :: 2. Suspath Check
        if not defined blocked (
            findstr /i /g:"%suspath_file%" "!temp_line!" >nul 2>&1
            if !errorlevel! equ 0 set "blocked=suspath"
        )

        :: 3. Output Logic
        if defined blocked (
            if "!SILENT!"=="0" echo( & echo [BLOCKED] !blocked! at line !current_ln!
            >>"%output%" echo(rem DISABLED [!blocked!] !line!
        ) else (
            set "final_line=!line:@\="%sandbox_path%\"!"
            >>"%output%" echo(!final_line!
        )
    )
    
    for /f "delims=" %%A in ("!current_ln!") do (
        endlocal
        set "total_lines=%%A"
    )
)

if exist "!temp_line!" del "!temp_line!"
if "%SILENT%"=="0" (
    echo(
    echo [SUCCESS] Processed %total_lines% lines.
)