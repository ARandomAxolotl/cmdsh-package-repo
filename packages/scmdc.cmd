@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem --- Setup ANSI Colors ---
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "cRed=%ESC%[91m"
set "cGreen=%ESC%[92m"
set "cYellow=%ESC%[93m"
set "cCyan=%ESC%[96m"
set "cReset=%ESC%[0m"

rem --- Installer ---
if "%~1" == "--installer" (
    echo %cCyan%[INFO] Downloading security rules...%cReset%
    if not exist "%~dp0..\.config" mkdir "%~dp0..\.config"
    cd /d "%~dp0..\.config"
    curl -sL https://raw.githubusercontent.com/ARandomAxolotl/cmdsh-package-repo/main/suscmd.txt --output suscmd.txt
    curl -sL https://raw.githubusercontent.com/ARandomAxolotl/cmdsh-package-repo/main/suspath.txt --output suspath.txt
    echo %cGreen%[SUCCESS] Files downloaded to .config folder!%cReset%
    goto :eof
)

rem --- Initialize Flags ---
set "SILENT=0"
set "DEBUG=0"
set "VERBOSE=0"
set "IS_BAT=0"
set "INPUT_FILE="

rem --- Parse Arguments ---
:parse_args
if "%~1"=="" goto :validate
if /i "%~1"=="-s" (set "SILENT=1" & shift & goto :parse_args)
if /i "%~1"=="-d" (set "DEBUG=1" & shift & goto :parse_args)
if /i "%~1"=="-v" (set "VERBOSE=1" & shift & goto :parse_args)
if /i "%~1"=="-b" (set "IS_BAT=1" & shift & goto :parse_args)

if not defined INPUT_FILE (set "INPUT_FILE=%~1")
shift
goto :parse_args

:validate
if "%VERBOSE%"=="1" @echo on
if not defined INPUT_FILE (
    echo %cRed%[ERROR] No input file specified.%cReset%
    echo %cYellow%Usage: scmdc [-s] [-d] [-v] ^<filename^>%cReset%
    exit /b 1
)

rem --- Setup Paths ---
for %%A in ("%~dp0..") do set "base_dir=%%~fA"
set "script_name=%INPUT_FILE%"
set "sandbox_path=%base_dir%\sandbox\%script_name%"

if not exist "%base_dir%\.config" mkdir "%base_dir%\.config"
if not exist "%base_dir%\sandbox\%script_name%" mkdir "%base_dir%\sandbox\%script_name%"

set "suspath_file=%base_dir%\.config\suspath.txt"
set "suscmd_file=%base_dir%\.config\suscmd.txt"

rem --- Failsafe & File Prep ---
if not exist "%suscmd_file%" (
    echo %cRed%[ERROR] Security file missing: %suscmd_file%%cReset%
    echo %cYellow%Please run the installer first: call ./functions/scmdc --installer%cReset%
    exit /b 1
)
if not exist "%suspath_file%" (
    echo %cRed%[ERROR] Security file missing: %suspath_file%%cReset%
    echo %cYellow%Please run the installer first: call ./functions/scmdc --installer%cReset%
    exit /b 1
)

rem Rebuild files to ensure pure Windows format (fixes github curl bugs)
set "clean_suscmd=%temp%\cmdsh_suscmd.txt"
set "clean_suspath=%temp%\cmdsh_suspath.txt"
(for /f "usebackq delims=" %%A in ("%suscmd_file%") do echo(%%A)>"%clean_suscmd%"
(for /f "usebackq delims=" %%A in ("%suspath_file%") do echo(%%A)>"%clean_suspath%"

rem --- Input/Output Setup ---
if "%IS_BAT%"=="1" (
    set "input=%INPUT_FILE%.sbat"
    set "output=%INPUT_FILE%.bat"
) else (
    set "input=%INPUT_FILE%.scmd"
    set "output=%INPUT_FILE%.cmd"
)

if not exist "%input%" (
    if "%SILENT%"=="0" echo %cRed%[ERROR] File "%input%" not found.%cReset%
    exit /b 1
)

set "total_lines=0"
set "temp_line=%temp%\cmdsh_line_%RANDOM%.tmp"
type nul > "%output%"

if "%SILENT%"=="0" echo %cCyan%[INFO] Compiling %input% to %output%...%cReset%

rem --- Main Loop ---
for /f "delims=" %%L in ('findstr /n "^" "%input%"') do (
    set "raw_line=%%L"
    
    setlocal EnableDelayedExpansion
    set "line=!raw_line:*:=!"
    set /a "current_ln=!total_lines! + 1"

    rem Logging for -d (Debug) and progress dots
    if "!DEBUG!"=="1" (
        if "!SILENT!"=="0" echo %cYellow%[DEBUG] Processing line !current_ln!: "!line!"%cReset%
    ) else (
        if "!SILENT!"=="0" <nul set /p "=%cCyan%.%cReset%"
    )

    if not defined line (
        >>"%output%" echo(
    ) else (
        rem 1. Clean line and write exactly without trailing spaces!
        set "clean_line=!line:^=!"
        >"!temp_line!" echo(!clean_line!
        
        set "blocked="
        
        rem 2. Suscmd Check: /L (Literal text) + /W (Whole word)
        findstr /i /L /w /g:"%clean_suscmd%" "!temp_line!" >nul 2>&1
        if !errorlevel! equ 0 set "blocked=suscmd"
        
        rem 3. Suspath Check: /L (Literal text)
        if not defined blocked (
            findstr /i /L /g:"%clean_suspath%" "!temp_line!" >nul 2>&1
            if !errorlevel! equ 0 set "blocked=suspath"
        )

        rem 4. Output Logic
        if defined blocked (
            if "!SILENT!"=="0" echo( & echo %cRed%[BLOCKED] !blocked! detected at line !current_ln!%cReset%
            >>"%output%" echo(rem DISABLED [!blocked!] !line!
        ) else (
            set "final_line=!line:@\=%sandbox_path%\!"
            >>"%output%" echo(!final_line!
        )
    )
    
    for /f "delims=" %%A in ("!current_ln!") do (
        endlocal
        set "total_lines=%%A"
    )
)

rem Cleanup temp files
if exist "!temp_line!" del "!temp_line!"
if exist "%clean_suscmd%" del "%clean_suscmd%"
if exist "%clean_suspath%" del "%clean_suspath%"

if "%SILENT%"=="0" (
    echo(
    echo %cGreen%[SUCCESS] Processed %total_lines% lines.%cReset%
)