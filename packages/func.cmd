@echo off
setlocal enabledelayedexpansion

:: --- Configuration & Paths ---
:: Get the true ESC character to ensure colors work even after copy-pasting
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "baseDir=%~dp0.."
set "configDir=!baseDir!\.config"
set "configPath=!configDir!\funcpath"
set "saveDir=!configDir!\saved"
set "backupDir=!configDir!\backup"
set "funcDir=%~dp0"

:: --- Initialization ---
if not exist "!configDir!" mkdir "!configDir!"
if not exist "!saveDir!" mkdir "!saveDir!"
if not exist "!backupDir!" mkdir "!backupDir!"
if not exist "!configPath!" (
    (
        echo # Default Repository
        echo https://raw.githubusercontent.com/ARandomAxolotl/cmdsh-package-repo/main/
        echo # Add more GitHub Raw URLs below
    ) > "!configPath!"
)

:: --- Command Router ---
set "cmd=%~1"
set "target=%~2"

:: Intercept Help Flags (e.g., func install -h)
if /i "!target!" == "-h" set "helpSubject=!cmd!" & set "cmd=help"
if /i "!target!" == "--help" set "helpSubject=!cmd!" & set "cmd=help"

if /i "!cmd!" == "help"           goto :help
if /i "!cmd!" == "-h"             goto :help
if /i "!cmd!" == "--help"         goto :help

if /i "!cmd!" == "install"        goto :install
if /i "!cmd!" == "uninstall"      goto :uninstall
if /i "!cmd!" == "undo"           goto :undo
if /i "!cmd!" == "list"           goto :list
if /i "!cmd!" == "update"         goto :update
if /i "!cmd!" == "add-repo"       goto :addrepo
if /i "!cmd!" == "remove-repo"    goto :removerepo
if /i "!cmd!" == "full-upgrade"   goto :fullupgrade
if /i "!cmd!" == "search"         goto :search
if /i "!cmd!" == "remake-config"  goto :remake

:: Aliases
if /i "!cmd!" == "remove"         goto :uninstall
if /i "!cmd!" == "update-source"  goto :update
if /i "!cmd!" == "addrepo"        goto :addrepo
if /i "!cmd!" == "removerepo"     goto :removerepo
if /i "!cmd!" == "upgrade"        goto :fullupgrade
if /i "!cmd!" == "remake"         goto :remake

:: Default fallback if no command matches
if "!cmd!"=="" goto :help
echo %ESC%[31m[Error]%ESC%[0m Unknown command: "!cmd!"
echo Run '%~n0 help' for usage information.
goto :end

:: --- Logic Blocks ---

:help
:: If helpSubject is empty, use target (e.g., "func help install")
if "!helpSubject!"=="" set "helpSubject=!target!"
if /i "!helpSubject!"=="" (
    echo %ESC%[33mcSH Package Manager%ESC%[0m
    echo Usage: %~n0 [command] [options]
    echo(
    echo %ESC%[36mCommands:%ESC%[0m
    echo   %ESC%[32minstall%ESC%[0m        Install a package from cached repositories
    echo   %ESC%[32muninstall%ESC%[0m      Move an installed package to backup cache
    echo   %ESC%[32mundo%ESC%[0m           Restore the last uninstalled package
    echo   %ESC%[32mlist%ESC%[0m           List available or installed packages
    echo   %ESC%[32mupdate%ESC%[0m         Fetch latest index from all configured repositories
    echo   %ESC%[32mfull-upgrade%ESC%[0m   Upgrade all installed packages to their latest versions
    echo   %ESC%[32msearch%ESC%[0m         Search for packages by keyword
    echo   %ESC%[32madd-repo%ESC%[0m       Add a new repository URL to config
    echo   %ESC%[32mremove-repo%ESC%[0m    Remove a repository URL from config
    echo   %ESC%[32mhelp%ESC%[0m           Display this help menu
    echo(
    echo %ESC%[90mTip: Run '%~n0 [command] --help' for specific command details.%ESC%[0m
    goto :end
)

:: Specific Command Helps
echo %ESC%[33mHelp for command: !helpSubject!%ESC%[0m
if /i "!helpSubject!"=="install" (
    echo Usage: %~n0 install ^<package_name^>
    echo Resolves dependencies and installs the specified package.
) else if /i "!helpSubject!"=="uninstall" (
    echo Usage: %~n0 uninstall ^<package_name^>
    echo Backs up and removes the specified package script from active use.
    echo Alias: remove
) else if /i "!helpSubject!"=="undo" (
    echo Usage: %~n0 undo
    echo Restores the most recently uninstalled package from the backup folder.
) else if /i "!helpSubject!"=="add-repo" (
    echo Usage: %~n0 add-repo ^<url^>
    echo Adds a raw GitHub URL to your config for package fetching.
) else if /i "!helpSubject!"=="remove-repo" (
    echo Usage: %~n0 remove-repo ^<url^>
    echo Removes the specified URL from your config file.
) else if /i "!helpSubject!"=="full-upgrade" (
    echo Usage: %~n0 full-upgrade
    echo Checks all currently installed packages and re-downloads them from the cache.
    echo Make sure to run '%~n0 update' first to get the latest cache.
    echo Alias: upgrade
) else if /i "!helpSubject!"=="list" (
    echo Usage: %~n0 list [--installed]
    echo Lists all available packages in the cache. 
    echo Add '--installed' to see what is currently on your system.
) else if /i "!helpSubject!"=="help" (
    echo Really? You need help with the help command? 
    echo Usage: %~n0 help [command]
) else (
    echo No specific help available for "!helpSubject!".
)
goto :end

:install
if "!target!"=="" ( echo %ESC%[31m[Error]%ESC%[0m Please specify a package to install. & goto :end )
echo %ESC%[36mPreparing to install "!target!"...%ESC%[0m
call :install_pkg "!target!" "normal"
goto :end

:install_pkg
:: Ensure local scope for recursive function calls
setlocal enabledelayedexpansion
set "pkgToInstall=%~1"
set "installMode=%~2"

:: Skip file existence check if in "force" mode (used for full-upgrade)
if /i not "!installMode!"=="force" (
    if exist "!funcDir!!pkgToInstall!.cmd" (
        echo %ESC%[33m[Notice]%ESC%[0m !pkgToInstall! is already installed.
        endlocal
        exit /b
    )
)

set "found=false"
set "winnerUrl="
set "pkgDeps=none"
set "pkgVer="

:: Find the package in all cached index files
for %%F in ("!saveDir!\*.txt") do (
    if "!found!"=="false" (
        REM Extract base URL from cache file name
        set "urlName=%%~nF"
        set "urlName=!urlName:_=/!"
        set "urlName=https://!urlName!"
        
        set "inPkg=false"
        for /f "usebackq tokens=1,* delims=:" %%A in ("%%F") do (
            set "key=%%A" & set "key=!key: =!"
            set "val=%%B"
    
            if defined val for /f "tokens=* delims= " %%V in ("!val!") do set "val=%%V"
           
            if "!key:~0,7!"=="package" (
                if /i "!val!"=="!pkgToInstall!" (
                    set "inPkg=true"
                    set "found=true"
                    set "winnerUrl=!urlName!/"
                ) else (
                    set "inPkg=false"
                )
            )
     
            if "!inPkg!"=="true" (
                if "!key!"=="dependencies" set "pkgDeps=!val!"
                if "!key!"=="version" set "pkgVer=!val!"
            )
        )
    )
)

if "!found!"=="true" (
    echo %ESC%[36mFound !pkgToInstall! v!pkgVer!.%ESC%[0m
    
    REM Process Dependencies
    if not "!pkgDeps!"=="none" if not "!pkgDeps!"=="" (
        echo %ESC%[33mResolving dependencies: !pkgDeps!%ESC%[0m
        for /f "tokens=1 delims=><=" %%D in ("!pkgDeps!") do (
            set "depName=%%D"
            for /f "tokens=* delims= " %%T in ("!depName!") do set "depName=%%T"
            
            echo %ESC%[35mInstalling dependency: !depName!%ESC%[0m
            call :install_pkg "!depName!" "normal"
        )
    )
    
    REM Download the actual cmd file
    echo %ESC%[36mDownloading !pkgToInstall!.cmd...%ESC%[0m
    curl -f -sL "!winnerUrl!!pkgToInstall!.cmd" --output "!funcDir!!pkgToInstall!.cmd"
    if not errorlevel 1 (
        echo %ESC%[32m[Success]%ESC%[0m Installed !pkgToInstall!
    ) else (
        echo %ESC%[31m[Error]%ESC%[0m Failed to download !pkgToInstall!.cmd
        if exist "!funcDir!!pkgToInstall!.cmd" del "!funcDir!!pkgToInstall!.cmd"
    )
) else (
    echo %ESC%[31m[Error]%ESC%[0m Function "!pkgToInstall!" not found in any repository.
    echo %ESC%[90mTip: Run 'update' to refresh your package list.%ESC%[0m
)
:: Close local variable scope
endlocal
exit /b

:removerepo
if "!target!"=="" ( echo %ESC%[31m[Error]%ESC%[0m No URL provided. & goto :end )
echo %ESC%[36mAttempting to remove "!target!" from config...%ESC%[0m
:: Use findstr /V /I /C to write all lines NOT containing the target URL to a temporary file
findstr /V /I /C:"!target!" "!configPath!" > "!configPath!.tmp"
move /y "!configPath!.tmp" "!configPath!" >nul
echo %ESC%[32m[Success]%ESC%[0m Repository removed (if it existed).
echo %ESC%[90mTip: Run 'update' to clear old cache files.%ESC%[0m
goto :end

:fullupgrade
echo %ESC%[36mUpgrading all installed packages...%ESC%[0m
set "upgradeCount=0"
:: Loop through all .cmd files in the current directory
for %%F in ("!funcDir!*.cmd") do (
    :: Skip the func.cmd file itself
    if /i not "%%~nxF"=="%~nx0" (
        set "pkgName=%%~nF"
        echo(
        echo %ESC%[35m=== Upgrading: !pkgName! ===%ESC%[0m
        :: Call install function with "force" flag to bypass existence check
        call :install_pkg "!pkgName!" "force"
        set /a upgradeCount+=1
    )
)
echo(
if !upgradeCount! equ 0 (
    echo %ESC%[33mNo external packages found to upgrade.%ESC%[0m
) else (
    echo %ESC%[32m[Success]%ESC%[0m Upgrade complete for !upgradeCount! packages.
)
goto :end

:addrepo
if "!target!"=="" ( echo %ESC%[31m[Error]%ESC%[0m No URL provided. & goto :end )
findstr /C:"!target!" "!configPath!" >nul
if %errorlevel% == 0 (
    echo %ESC%[33m[Notice]%ESC%[0m Repository already exists.
) else (
    :: Append to config. The >> is placed at the front to avoid trailing spaces in the URL.
    >>"!configPath!" echo !target!
    echo %ESC%[32m[Success]%ESC%[0m Repository added.
)
goto :end

:search
if "!target!"=="" ( echo %ESC%[31m[Error]%ESC%[0m Specify a keyword. & goto :end )
echo %ESC%[36mSearching cached repositories for "!target!"...%ESC%[0m
set "matchCount=0"

for %%F in ("!saveDir!\*.txt") do (
    set "pkgName=" & set "pkgDesc=" & set "pkgVer="
    set "printMe=false"
    
    for /f "usebackq tokens=1,* delims=:" %%A in ("%%F") do (
        set "key=%%A" & set "key=!key: =!"
        set "val=%%B"
        if defined val for /f "tokens=* delims= " %%V in ("!val!") do set "val=%%V"
        
        if "!key:~0,7!"=="package" (
            if "!printMe!"=="true" (
                echo  - %ESC%[32m!pkgName!%ESC%[0m v!pkgVer! : !pkgDesc!
                set /a matchCount+=1
            )
            set "pkgName=!val!" & set "pkgDesc=N/A" & set "pkgVer=1" & set "printMe=false"
        )
        if "!key!"=="description" set "pkgDesc=!val!"
        if "!key!"=="version" set "pkgVer=!val!"
        
        echo "!val!" | findstr /i /c:"!target!" >nul
        if !errorlevel! equ 0 set "printMe=true"
    )
    if "!printMe!"=="true" (
        echo  - %ESC%[32m!pkgName!%ESC%[0m v!pkgVer! : !pkgDesc!
        set /a matchCount+=1
    )
)

if !matchCount! equ 0 (
    echo %ESC%[31mNo matches found.%ESC%[0m
) else (
    echo(
    echo %ESC%[32mSearch complete. Found !matchCount! matching packages.%ESC%[0m
)
goto :end

:update
echo %ESC%[36mUpdating repository indexes...%ESC%[0m
:: Clean up old caches before updating to remove dead sub-repos
del /q "!saveDir!\*.txt" 2>nul

for /f "usebackq tokens=*" %%U in (`findstr /V /B "#" "!configPath!"`) do (
    call :fetch_repo "%%U"
)
goto :end

:: --- Recursive Fetch Function for Meta-Repos ---
:fetch_repo
setlocal enabledelayedexpansion
set "url=%~1"
if not "!url:~-1!"=="/" set "url=!url!/"

:: Format URL into a valid filename
set "sName=!url:https://=!" & set "sName=!sName:/=_!" & set "sName=!sName::=!"

echo %ESC%[33mFetching: !url!csh-repo-index.txt%ESC%[0m
set "tempFile=!saveDir!\temp_!RANDOM!.txt"
curl -f -L -s "!url!csh-repo-index.txt" > "!tempFile!"

if !errorlevel! equ 0 (
    set "isMeta=false"
    REM Check if it's a meta-repo
    for /f "usebackq tokens=1,* delims=:" %%A in ("!tempFile!") do (
        set "key=%%A" & set "key=!key: =!"
        set "val=%%B"
        if defined val for /f "tokens=* delims= " %%V in ("!val!") do set "val=%%V"
        if /i "!key!"=="type" if /i "!val!"=="meta-repo" set "isMeta=true"
    )
    
    if "!isMeta!"=="true" (
        echo %ESC%[35m[Meta-Repo] Resolving sub-repositories for !url!...%ESC%[0m
        for /f "usebackq tokens=1,* delims=:" %%A in ("!tempFile!") do (
            set "key=%%A" & set "key=!key: =!"
            set "val=%%B"
            if defined val for /f "tokens=* delims= " %%V in ("!val!") do set "val=%%V"
            
            if "!key:~0,4!"=="repo" (
                set "subUrl=!val!"
                REM Replace @ with the base URL
                if "!subUrl:~0,1!"=="@" set "subUrl=!url!!subUrl:~1!"
                call :fetch_repo "!subUrl!"
            )
        )
        REM Delete the meta-repo index as it doesn't contain actual packages
        del "!tempFile!"
    ) else (
        move /y "!tempFile!" "!saveDir!\!sName!.txt" >nul
        echo %ESC%[32m✔ Cached Packages.%ESC%[0m
    )
) else (
    echo %ESC%[31m✖ Failed to fetch index for !url!%ESC%[0m
    if exist "!tempFile!" del "!tempFile!"
)
endlocal
exit /b

:list
if /i "!target!" == "--installed" goto :list_installed
echo %ESC%[36mAvailable Packages (Cached):%ESC%[0m
for %%F in ("!saveDir!\*.txt") do (
    REM Reconstruct URL from filename for display
    set "urlName=%%~nF"
    set "urlName=!urlName:_=/!"
    echo(
    echo %ESC%[33m--- Source: https://!urlName!---%ESC%[0m
    
    set "pkgName=" & set "pkgDesc=" & set "pkgVer=" & set "pkgDeps="
    for /f "usebackq tokens=1,* delims=:" %%A in ("%%F") do (
        set "key=%%A" & set "key=!key: =!"
        set "val=%%B"
        if defined val for /f "tokens=* delims= " %%V in ("!val!") do set "val=%%V"
        
        if "!key:~0,7!"=="package" (
            if defined pkgName echo  - %ESC%[32m!pkgName!%ESC%[0m v!pkgVer! : !pkgDesc! %ESC%[90m[Deps: !pkgDeps!]%ESC%[0m
            set "pkgName=!val!" & set "pkgDesc=N/A" & set "pkgVer=1" & set "pkgDeps=none"
        )
        if "!key!"=="description" set "pkgDesc=!val!"
        if "!key!"=="version" set "pkgVer=!val!"
        if "!key!"=="dependencies" set "pkgDeps=!val!"
    )
    if defined pkgName echo  - %ESC%[32m!pkgName!%ESC%[0m v!pkgVer! : !pkgDesc! %ESC%[90m[Deps: !pkgDeps!]%ESC%[0m
)
goto :end

:list_installed
echo %ESC%[36mInstalled Packages:%ESC%[0m
for %%F in ("!funcDir!*.cmd") do (
    if /i not "%%~nxF"=="%~nx0" (
        set "fTime=%%~tF"
        echo  - %ESC%[32m%%~nF%ESC%[0m %ESC%[90m[!fTime!]%ESC%[0m
    )
)
goto :end

:uninstall
if "!target!"=="" ( echo %ESC%[31m[Error]%ESC%[0m Please specify a package to uninstall. & goto :end )
if exist "!funcDir!!target!.cmd" ( 
    move /y "!funcDir!!target!.cmd" "!backupDir!\!target!.cmd" >nul
    echo %ESC%[32m[Success]%ESC%[0m Uninstalled "!target!" and moved to backup cache.
) else ( 
    echo %ESC%[31m[Error]%ESC%[0m Package "!target!" not found. 
)
goto :end

:undo
:: Find the most recently modified/added file in the backup folder
set "lastBackup="
for /f "delims=" %%I in ('dir "!backupDir!\*.cmd" /b /o-d 2^>nul') do (
    if not defined lastBackup set "lastBackup=%%I"
)

if defined lastBackup (
    set "pkgName=!lastBackup:.cmd=!"
    move /y "!backupDir!\!lastBackup!" "!funcDir!!lastBackup!" >nul
    echo %ESC%[32m[Success]%ESC%[0m Restored last uninstalled package: !pkgName!
) else (
    echo %ESC%[31m[Error]%ESC%[0m No package found in backup history to restore.
)
goto :end

:remake
(
    echo # Default Repository
    echo https://raw.githubusercontent.com/ARandomAxolotl/cmdsh-package-repo/main/
) > "!configPath!"
echo %ESC%[32m[Success]%ESC%[0m Config reset.
goto :end

:end
endlocal