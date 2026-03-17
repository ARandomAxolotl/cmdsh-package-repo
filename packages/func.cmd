@echo off
setlocal enabledelayedexpansion

:: --- Configuration & Paths ---
:: Using %~dp0 here refers to the Functions folder. 
:: We go up one level to find the .config folder created by cmdsh.cmd.
set "ESC="
set "baseDir=%~dp0.."
set "configDir=!baseDir!\.config"
set "configPath=!configDir!\funcpath"
set "saveDir=!configDir!\saved"
set "funcDir=%~dp0"

:: --- Initialization ---
if not exist "!configDir!" mkdir "!configDir!" [cite: 2]
if not exist "!saveDir!" mkdir "!saveDir!"
if not exist "!configPath!" (
    (
        echo # Default Repository
        echo https://raw.githubusercontent.com/ARandomAxolotl/cmdSH/main/Functions/
        echo # Add more GitHub Raw URLs below
    ) > "!configPath!"
)

:: --- Command Router ---
set "cmd=%~1"
set "target=%~2"

if /i "!cmd!" == "install"        goto :install
if /i "!cmd!" == "uninstall"      goto :uninstall
if /i "!cmd!" == "list"           goto :list
if /i "!cmd!" == "update"         goto :update
if /i "!cmd!" == "add-repo"       goto :addrepo
if /i "!cmd!" == "search"         goto :search
if /i "!cmd!" == "remake-config"  goto :remake
if /i "!cmd!" == "purge"          goto :purge

if /i "!cmd!" == "remove" goto :uninstall
if /i "!cmd!" == "update-source" goto :update
if /i "!cmd!" == "addrepo" goto :addrepo
if /i "!cmd!" == "remake" goto :remake
:: addional commands

echo %ESC%[33mcSH Package Manager%ESC%[0m
echo Usage: %~n0 [install ^| uninstall ^| list ^| update ^| add-repo ^| search ^| purge]
goto :end

:: --- Logic Blocks ---

:install
set "found=false"
echo %ESC%[36mSearching repositories...%ESC%[0m
for /f "usebackq tokens=*" %%U in (`findstr /V /B "#" "!configPath!"`) do (
    if "!found!"=="false" (
        curl -f -s "%%U!target!.cmd" --output "!funcDir!!target!.cmd"
        if not errorlevel 1 ( set "found=true" & set "winner=%%U" )
    )
)
if "!found!"=="true" (
    echo %ESC%[32m[Success]%ESC%[0m Installed !target! from !winner!
) else (
    echo %ESC%[31m[Error]%ESC%[0m Function "!target!" not found.
    if exist "!funcDir!!target!.cmd" del "!funcDir!!target!.cmd"
)
goto :end

:addrepo
if "!target!" == "" ( echo %ESC%[31m[Error]%ESC%[0m No URL provided. & goto :end )
findstr /C:"!target!" "!configPath!" >nul
if %errorlevel% == 0 (
    echo %ESC%[33m[Notice]%ESC%[0m Repository already exists.
) else (
    echo !target! >> "!configPath!"
    echo %ESC%[32m[Success]%ESC%[0m Repository added.
)
goto :end

:search
if "!target!"=="" (
    echo %ESC%[31m[Error]%ESC%[0m Specify a keyword.
    goto :end
)

echo %ESC%[36mSearching repositories for functions containing "!target!"...%ESC%[0m
set "matchCount=0"

:: Loop through all cache files in the save directory
for %%F in ("!saveDir!\*.txt") do (
    :: Check if the file contains the keyword before doing anything
    findstr /i /c:"!target!" "%%F" >nul
    if !errorlevel! equ 0 (
        echo(
        echo %ESC%[33m[Repo: %%~nF]%ESC%[0m
        
        :: Read lines that match the keyword
        for /f "usebackq tokens=*" %%A in (`findstr /i /c:"!target!" "%%F"`) do (
            echo    - %%A
            set /a matchCount+=1
        )
    )
)

echo(
if !matchCount! equ 0 (
    echo %ESC%[31mNo matches found.%ESC%[0m
    echo %ESC%[90mTip: If you haven't recently, run 'update' to populate the cache.%ESC%[0m
) else (
    echo %ESC%[32mSearch complete. Found !matchCount! matching function(s).%ESC%[0m
)
goto :end

:update
echo %ESC%[36mUpdating Caches...%ESC%[0m
for /f "usebackq tokens=*" %%U in (`findstr /V /B "#" "!configPath!"`) do (
    set "url=%%U"
    set "api=!url:raw.githubusercontent.com=api.github.com/repos!"
    set "api=!api:/main/=/contents/!"
    set "api=!api:/master/=/contents/!"
    
    :: Clean name for local storage
    set "sName=%%U"
    set "sName=!sName:https://=!"
    set "sName=!sName:http://=!"
    set "sName=!sName:/=_!"
    set "sName=!sName::=!"
    
    :: Bazzite/Fedora style orbit spinner
    set "spinChars=⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    set "idx=0"

    echo %ESC%[33mFetching: %%U%ESC%[0m
    curl -L -H "User-Agent: cmdSH" -s "!api!" > "!saveDir!\temp.json"
    
    if exist "!saveDir!\!sName!.txt" del "!saveDir!\!sName!.txt"
    
    :: Logic to split giant JSON lines into a clean list
    for /f "usebackq delims=" %%L in ("!saveDir!\temp.json") do (
        set "line=%%L"
        set "line=!line:,= !"
        for %%A in (!line!) do (
            set "item=%%~A"
            
            :: Update the Bazzite-style Spinner
            set /a "idx=(idx+1)%%10"
            for %%i in (!idx!) do set "char=!spinChars:~%%i,1!"
            <nul set /p "=%ESC%[s%ESC%[32m!char! %ESC%[37mProcessing...%ESC%[u"

            echo !item! | findstr /i "name" >nul
            if !errorlevel! == 0 (
                for /f "tokens=2 delims=:" %%B in ("!item!") do (
                    set "clean=%%~B"
                    if /i "!clean:~-4!" == ".cmd" (
                        set "final=!clean:.cmd=!"
                        echo !final!>>"!saveDir!\!sName!.txt"
                    )
                )
            )
        )
    )
    echo %ESC%[K%ESC%[32m✔ Done.%ESC%[0m
    if exist "!saveDir!\temp.json" del "!saveDir!\temp.json"
)
:list
if /i "!target!" == "--installed" goto :list_installed
echo %ESC%[36mAvailable (Cached):%ESC%[0m
for %%F in ("!saveDir!\*.txt") do (
    echo %ESC%[33mSource: %%~nxF%ESC%[0m
    if exist "%%F" (
        for /f "usebackq tokens=*" %%A in ("%%F") do echo  - %%A
    )
)
goto :end

:list_installed
echo %ESC%[36mInstalled:%ESC%[0m
for %%F in ("!funcDir!*.cmd") do (
    set "fTime=%%~tF"
    echo  - %%~nF %ESC%[90m[!fTime!]%ESC%[0m
)
goto :end

:uninstall
if exist "!funcDir!!target!.cmd" ( 
    del "!funcDir!!target!.cmd" 
    echo %ESC%[32m[Success]%ESC%[0m Uninstalled. 
) else ( 
    echo %ESC%[31m[Error]%ESC%[0m Not found. 
)
goto :end

:remake
(
    echo # Default Repository
    echo https://raw.githubusercontent.com/ARandomAxolotl/cmdSH/main/Functions/
    echo https://raw.githubusercontent.com/ARandomAxolotl/cmdsh-package-repo/main/
) > "!configPath!"
echo %ESC%[32m[Success]%ESC%[0m Config reset.
goto :end

:purge
set /p "conf=Purge all? (y/N): "
if /i "!conf!"=="y" ( 
    rd /s /q "!funcDir!"
    rd /s /q "!configDir!"
    echo %ESC%[31mPurged. Restart shell to re-initialize.%ESC%[0m
    exit /b 
)
goto :end

:end
endlocal
