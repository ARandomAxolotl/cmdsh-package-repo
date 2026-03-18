@echo off
setlocal enabledelayedexpansion

:: --- Configuration & Paths ---
set "ESC= "
set "baseDir=%~dp0.."
set "configDir=!baseDir!\.config_man"
set "configPath=!configDir!\manpath"
set "saveDir=!configDir!\saved"
set "manDir=%~dp0man_pages\"

:: --- Initialization ---
if not exist "!configDir!" mkdir "!configDir!"
if not exist "!saveDir!" mkdir "!saveDir!"
if not exist "!manDir!" mkdir "!manDir!"
if not exist "!configPath!" (
    (
        echo # Default Manual Repository (Meta-Repo)
        echo https://raw.githubusercontent.com/ARandomAxolotl/cmdsh-package-repo/main/
    ) > "!configPath!"
)

:: --- Command Router ---
set "cmd=%~1"
set "target=%~2"

if /i "!cmd!" == "update"  goto :update
if /i "!cmd!" == "install" goto :install
if /i "!cmd!" == "list"    goto :list
if /i "!cmd!" == "remove"  goto :uninstall
if /i "!cmd!" == "purge"   goto :purge
if /i "!cmd!" == ""        goto :help

:: Default action: View the manual page
goto :view_man

:help
echo %ESC%[33mcSH Manual Manager%ESC%[0m
echo Usage: %~n0 [install ^| update ^| list ^| remove ^| ^<command_name^>]
goto :end

:: --- Logic Blocks ---

:update
echo %ESC%[36mRefreshing manual repository indexes...%ESC%[0m
del /q "!saveDir!\*.txt" 2>nul
for /f "usebackq tokens=*" %%U in (`findstr /V /B "#" "!configPath!"`) do (
    call :fetch_repo "%%U"
)
goto :end

:fetch_repo
setlocal enabledelayedexpansion
set "url=%~1"
if not "!url:~-1!"=="/" set "url=!url!/"
set "sName=!url:https://=!" & set "sName=!sName:/=_!" & set "sName=!sName::=!"

echo %ESC%[33mFetching: !url!csh-man-repo-index.txt%ESC%[0m
set "tempFile=!saveDir!\temp_!RANDOM!.txt"
curl -f -L -s "!url!csh-man-repo-index.txt" > "!tempFile!"

if !errorlevel! equ 0 (
    set "isMeta=false"
    for /f "usebackq tokens=1,* delims=:" %%A in ("!tempFile!") do (
        set "key=%%A" & set "key=!key: =!"
        set "val=%%B" & if defined val for /f "tokens=* delims= " %%V in ("!val!") do set "val=%%V"
        if /i "!key!"=="type" if /i "!val!"=="man-meta-repo" set "isMeta=true"
    )
    
    if "!isMeta!"=="true" (
        echo %ESC%[35m[Meta-Repo] Resolving sub-repositories for !url!...%ESC%[0m
        for /f "usebackq tokens=1,* delims=:" %%A in ("!tempFile!") do (
            set "key=%%A" & set "key=!key: =!"
            set "val=%%B" & if defined val for /f "tokens=* delims= " %%V in ("!val!") do set "setVal=%%V"
            if "!key:~0,4!"=="repo" (
                set "subUrl=!setVal!"
                if "!subUrl:~0,1!"=="@" set "subUrl=!url!!subUrl:~1!"
                call :fetch_repo "!subUrl!"
            )
        )
        del "!tempFile!"
    ) else (
        move /y "!tempFile!" "!saveDir!\!sName!.txt" >nul
        echo %ESC%[32m✔ Cached Manual Index.%ESC%[0m
    )
) else (
    echo %ESC%[31m✖ Failed to fetch index for !url!%ESC%[0m
    if exist "!tempFile!" del "!tempFile!"
)
endlocal
exit /b

:install
if "!target!"=="" ( echo %ESC%[31m[Error]%ESC%[0m Please specify a manual to install. & goto :end )
set "found=false"
for %%F in ("!saveDir!\*.txt") do (
    if "!found!"=="false" (
        for /f "usebackq tokens=1,* delims=:" %%A in ("%%F") do (
            set "key=%%A" & set "key=!key: =!"
            set "val=%%B" & if defined val for /f "tokens=* delims= " %%V in ("!val!") do set "val=%%V"
            if /i "!key:~0,7!"=="package" if /i "!val!"=="!target!" (
                set "found=true"
                set "urlName=%%~nF" & set "urlName=!urlName:_=/!" & set "urlName=https://!urlName!/"
                
                echo %ESC%[36mDownloading !target!.txt...%ESC%[0m
                curl -f -sL "!urlName!!target!.txt" --output "!manDir!!target!.txt"
                if not errorlevel 1 (
                    echo %ESC%[32m[Success] Manual installed. Displaying content:%ESC%[0m
                    echo %ESC%[90m--------------------------------------------------%ESC%[0m
                    type "!manDir!!target!.txt"
                    echo.
                    echo %ESC%[90m--------------------------------------------------%ESC%[0m
                ) else (
                    echo %ESC%[31m[Error] Failed to download !target!.txt%ESC%[0m
                )
            )
        )
    )
)
if "!found!"=="false" echo %ESC%[31m[Error] Manual "!target!" not found in any repository.%ESC%[0m
goto :end

:view_man
if exist "!manDir!!cmd!.txt" (
    echo %ESC%[33m--- Manual Page: !cmd! ---%ESC%[0m
    type "!manDir!!cmd!.txt"
) else (
    echo %ESC%[31m[Error] No manual entry for "!cmd!".%ESC%[0m
    echo %ESC%[90mTip: Try 'man install !cmd!' to download it.%ESC%[0m
)
goto :end

:list
echo %ESC%[36mInstalled Manuals:%ESC%[0m
for %%F in ("!manDir!*.txt") do echo  - %ESC%[32m%%~nF%ESC%[0m
goto :end

:uninstall
if exist "!manDir!!target!.txt" (
    del "!manDir!!target!.txt"
    echo %ESC%[32m[Success] Removed manual for !target!.%ESC%[0m
) else (
    echo %ESC%[31m[Error] Manual "!target!" is not installed.%ESC%[0m
)
goto :end

:purge
rd /s /q "!configDir!" 2>nul
rd /s /q "!manDir!" 2>nul
echo %ESC%[31mAll manual data purged.%ESC%[0m
goto :end

:end
endlocal