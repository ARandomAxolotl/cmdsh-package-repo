@echo off
setlocal enabledelayedexpansion

:: --- Configuration & Paths ---
set "ESC="
set "baseDir=%~dp0.."
set "configDir=!baseDir!\.config"
set "configPath=!configDir!\funcpath"
set "saveDir=!configDir!\saved"
set "funcDir=%~dp0"

:: --- Initialization ---
if not exist "!configDir!" mkdir "!configDir!"
if not exist "!saveDir!" mkdir "!saveDir!"
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

if /i "!cmd!" == "install"        goto :install
if /i "!cmd!" == "uninstall"      goto :uninstall
if /i "!cmd!" == "list"           goto :list
if /i "!cmd!" == "update"         goto :update
if /i "!cmd!" == "add-repo"       goto :addrepo
if /i "!cmd!" == "search"         goto :search
if /i "!cmd!" == "remake-config"  goto :remake

if /i "!cmd!" == "remove"         goto :uninstall
if /i "!cmd!" == "update-source"  goto :update
if /i "!cmd!" == "addrepo"        goto :addrepo
if /i "!cmd!" == "remake"         goto :remake

:: Help Screen
echo %ESC%[33mcSH Package Manager%ESC%[0m
echo Usage: %~n0 [install ^| uninstall ^| list ^| update ^| add-repo ^| search ]
goto :end

:: --- Logic Blocks ---

:install
if "!target!"=="" ( echo %ESC%[31m[Error]%ESC%[0m Please specify a package to install. & goto :end )
echo %ESC%[36mPreparing to install "!target!"...%ESC%[0m
call :install_pkg "!target!"
goto :end

:install_pkg
:: THÊM VÀO: Đảm bảo biến cục bộ cho hàm đệ quy
setlocal enabledelayedexpansion
set "pkgToInstall=%~1"
if exist "!funcDir!!pkgToInstall!.cmd" (
    echo %ESC%[33m[Notice]%ESC%[0m !pkgToInstall! is already installed.
    endlocal
    exit /b
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
            call :install_pkg "!depName!"
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
:: THÊM VÀO: Đóng môi trường biến cục bộ
endlocal
exit /b

:addrepo
if "!target!"=="" ( echo %ESC%[31m[Error]%ESC%[0m No URL provided. & goto :end )
findstr /C:"!target!" "!configPath!" >nul
if %errorlevel% == 0 (
    echo %ESC%[33m[Notice]%ESC%[0m Repository already exists.
) else (
    echo !target! >> "!configPath!"
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
    echo %ESC%[32mSearch complete. Found !matchCount! matching package(s).%ESC%[0m
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
    echo %ESC%[33m--- Source: https://!urlName! ---%ESC%[0m
    
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
    if /i not "%%~nxF"=="func.cmd" (
        set "fTime=%%~tF"
        echo  - %ESC%[32m%%~nF%ESC%[0m %ESC%[90m[!fTime!]%ESC%[0m
    )
)
goto :end

:uninstall
if exist "!funcDir!!target!.cmd" ( 
    del "!funcDir!!target!.cmd" 
    echo %ESC%[32m[Success]%ESC%[0m Uninstalled !target!.
) else ( 
    echo %ESC%[31m[Error]%ESC%[0m Package "!target!" not found. 
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