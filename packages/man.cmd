@echo off
setlocal enabledelayedexpansion

:: --- ESC character for ANSI colors ---
for /f "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
    set "DEL=%%a"
    set "ESC=%%b"
)

:: Enable Virtual Terminal Processing
reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1

:: --- Paths ---
for %%I in ("%~dp0..") do set "baseDir=%%~fI"

set "configDir=!baseDir!\.config"
set "configPath=!configDir!\funcpath"
set "saveDir=!configDir!\saved_man"
set "manDir=!baseDir!\.config\man_pages\"

:: --- Initialization ---
if not exist "!configDir!" mkdir "!configDir!"
if not exist "!saveDir!"   mkdir "!saveDir!"
if not exist "!manDir!"    mkdir "!manDir!"

:: --- Routing ---
set "target=%~1"
set "arg2=%~2"

if "!target!"=="" (
    echo !ESC![31m[Usage] man [install ^| update ^| list ^| remove ^| purge ^| ^<command^>]!ESC![0m
    exit /b 1
)
if /i "!target!"=="update"  ( call :update_indexes          & exit /b )
if /i "!target!"=="list"    ( call :cmd_list                & exit /b )
if /i "!target!"=="purge"   ( call :cmd_purge               & exit /b )
if /i "!target!"=="install" ( call :cmd_install "!arg2!"    & exit /b )
if /i "!target!"=="remove"  ( call :cmd_remove  "!arg2!"    & exit /b )

:: Default: view a manual page (auto-install if missing)
if exist "!manDir!!target!.txt" (
    call cat "!manDir!!target!.txt"
    exit /b
)
echo Manual "!target!" not found locally. Auto-installing...
call :do_install
exit /b

:: ===========================================================================
:cmd_list
echo !ESC![36mInstalled manual pages:!ESC![0m
set "_count=0"
for %%F in ("!manDir!*.txt") do (
    echo   !ESC![32m%%~nF!ESC![0m
    set /a "_count+=1"
)
if "!_count!"=="0" echo   !ESC![33m(none)!ESC![0m
goto :eof

:: ===========================================================================
:cmd_remove
set "_name=%~1"
if "!_name!"=="" (
    echo !ESC![31m[Usage] man remove ^<name^>!ESC![0m
    goto :eof
)
if exist "!manDir!!_name!.txt" (
    del /f /q "!manDir!!_name!.txt"
    echo !ESC![32m[Removed] !_name!!ESC![0m
) else (
    echo !ESC![31m[Error] Manual "!_name!" not found.!ESC![0m
)
goto :eof

:: ===========================================================================
:cmd_install
set "_name=%~1"
if "!_name!"=="" (
    echo !ESC![31m[Usage] man install ^<name^>!ESC![0m
    goto :eof
)
:: Reuse do_install via target variable
set "target=!_name!"
call :do_install
goto :eof

:: ===========================================================================
:cmd_purge
echo !ESC![33mPurging all manual pages and cached indexes...!ESC![0m
if exist "!manDir!"   ( rd /s /q "!manDir!"   && echo !ESC![90m  Removed man_pages!ESC![0m )
if exist "!saveDir!"  ( rd /s /q "!saveDir!"  && echo !ESC![90m  Removed saved_man!ESC![0m )
if exist "!configDir!" (
    :: Only remove config dir if empty after above deletions
    rd "!configDir!" >nul 2>&1 && echo !ESC![90m  Removed .config!ESC![0m
)
echo !ESC![32m✔ Purge complete.!ESC![0m
goto :eof

:: ===========================================================================
:: Fetch a file from either a local path or remote URL into a destination.
:: Usage: call :fetch_file <sourceURL> <destPath>
:fetch_file
set "_src=%~1"
set "_dst=%~2"

set "_isLocal=false"
if /i "!_src:~0,8!"=="file:///" set "_isLocal=true"
if /i "!_src:~0,7!"=="file://"  set "_isLocal=true"

if "!_isLocal!"=="true" (
    set "_localPath=!_src!"
    set "_localPath=!_localPath:file:///=!"
    set "_localPath=!_localPath:file://=!"
    set "_localPath=!_localPath:/=\!"
    copy /y "!_localPath!" "!_dst!" >nul 2>&1
) else (
    curl -f -sL "!_src!" --output "!_dst!"
)
goto :eof

:: ===========================================================================
:: Resolve a repo-N value against a base URL.
:: @ prefix = relative to base URL. No @ = absolute URL.
:: Result stored in _resolvedURL
:: Usage: call :resolve_repo_url <baseURL> <repoVal>
:resolve_repo_url
set "_base=%~1"
set "_rval=%~2"

:: Ensure base has trailing slash
if not "!_base:~-1!"=="/" set "_base=!_base!/"

if "!_rval:~0,1!"=="@" (
    :: Relative: strip @ and append to base
    set "_rel=!_rval:~1!"
    :: Ensure relative part has trailing slash
    if not "!_rel:~-1!"=="/" set "_rel=!_rel!/"
    set "_resolvedURL=!_base!!_rel!"
) else (
    :: Absolute URL — use as-is (ensure trailing slash)
    set "_resolvedURL=!_rval!"
    if not "!_resolvedURL:~-1!"=="/" set "_resolvedURL=!_resolvedURL!/"
)
goto :eof

:: ===========================================================================
:: Build a flat safe cache filename from a URL
:: Result stored in _safeName
:make_safe_name
set "_safeName=%~1"
set "_safeName=!_safeName:http://=!"
set "_safeName=!_safeName:https://=!"
set "_safeName=!_safeName:file:///=!"
set "_safeName=!_safeName:file://=!"
set "_safeName=!_safeName:/=_!"
set "_safeName=!_safeName::=_!"
goto :eof

:: ===========================================================================
:update_indexes
echo !ESC![36mRefreshing manual repository indexes...!ESC![0m
if not exist "!configPath!" (
    echo !ESC![31m[Error] Config file funcpath missing.!ESC![0m
    goto :eof
)

for /f "usebackq tokens=*" %%L in ("!configPath!") do (
    set "line=%%L"
    if defined line if not "!line:~0,1!"=="#" (
        set "rootURL=!line!"
        if not "!rootURL:~-1!"=="/" set "rootURL=!rootURL!/"

        :: --- Fetch root index ---
        call :make_safe_name "!rootURL!"
        set "rootSafe=!_safeName!"
        set "rootIndexCache=!saveDir!\!rootSafe!csh-man-repo-index.txt"

        echo Fetching root index: !rootURL!
        call :fetch_file "!rootURL!csh-man-repo-index.txt" "!rootIndexCache!"

        if not exist "!rootIndexCache!" (
            echo !ESC![31m[Error] Could not fetch root index from !rootURL!!ESC![0m
        ) else (
            :: Check if this is a meta-repo (type: man-meta-repo)
            set "isMeta=false"
            for /f "usebackq tokens=1,* delims=:" %%A in ("!rootIndexCache!") do (
                set "_k=%%A" & set "_k=!_k: =!"
                set "_v=%%B" & if defined _v for /f "tokens=* delims= " %%V in ("!_v!") do set "_v=%%V"
                if /i "!_k!"=="type" if /i "!_v!"=="man-meta-repo" set "isMeta=true"
            )

            if "!isMeta!"=="true" (
                echo !ESC![90mMeta-repo detected. Resolving sub-repos...!ESC![0m

                :: Iterate repo-N entries and fetch each sub-repo index
                for /f "usebackq tokens=1,* delims=:" %%A in ("!rootIndexCache!") do (
                    set "_k=%%A" & set "_k=!_k: =!"
                    set "_v=%%B" & if defined _v for /f "tokens=* delims= " %%V in ("!_v!") do set "_v=%%V"

                    :: Match repo-N keys (repo- followed by digits)
                    set "_isRepo=false"
                    if /i "!_k:~0,5!"=="repo-" set "_isRepo=true"

                    if "!_isRepo!"=="true" if defined _v (
                        call :resolve_repo_url "!rootURL!" "!_v!"
                        set "subURL=!_resolvedURL!"

                        call :make_safe_name "!subURL!"
                        set "subSafe=!_safeName!"
                        set "subCache=!saveDir!\!subSafe!csh-man-repo-index.txt"

                        echo Fetching sub-repo: !subURL!
                        call :fetch_file "!subURL!csh-man-repo-index.txt" "!subCache!"

                        if exist "!subCache!" (
                            :: Save sidecar URL for do_install
                            echo !subURL!>"!saveDir!\!subSafe!csh-man-repo-index.url"
                        ) else (
                            echo !ESC![31m[Error] Could not fetch sub-repo index from !subURL!!ESC![0m
                        )
                    )
                )
            ) else (
                :: Plain repo — save sidecar directly
                echo !rootURL!>"!saveDir!\!rootSafe!csh-man-repo-index.url"
            )
        )
    )
)
echo !ESC![32m✔ Cached Manual Indexes.!ESC![0m
goto :eof

:: ===========================================================================
:do_install
echo !ESC![36mAuto-updating indexes before installation...!ESC![0m
call :update_indexes

set "found=false"

for %%F in ("!saveDir!\*.txt") do (
    if "!found!"=="false" (
        set "finalURL="

        if exist "%%~dpnF.url" (
            for /f "usebackq tokens=*" %%U in ("%%~dpnF.url") do (
                if not defined finalURL set "finalURL=%%U"
            )
        )

        if not defined finalURL (
            echo !ESC![33m[Warn] No sidecar for %%~nxF — skipping.!ESC![0m
        ) else (
            for /f "usebackq tokens=1,* delims=:" %%A in ("%%F") do (
                set "key=%%A"
                set "key=!key: =!"
                set "val=%%B"
                if defined val (
                    for /f "tokens=* delims= " %%V in ("!val!") do set "val=%%V"
                )

                if /i "!key:~0,7!"=="package" if /i "!val!"=="!target!" (
                    set "found=true"
                    echo !ESC![36mDownloading !target!.txt from !finalURL!...!ESC![0m
                    call :fetch_file "!finalURL!!target!.txt" "!manDir!!target!.txt"

                    if exist "!manDir!!target!.txt" (
                        echo !ESC![32m[Success] Manual installed. Displaying content:!ESC![0m
                        echo !ESC![90m--------------------------------------------------!ESC![0m
                        call cat "!manDir!!target!.txt"
                        echo.
                        echo !ESC![90m--------------------------------------------------!ESC![0m
                    ) else (
                        echo !ESC![31m[Error] Failed to download !target!.txt!ESC![0m
                    )
                )
            )
        )
    )
)

if "!found!"=="false" echo !ESC![31m[Error] Manual package "!target!" not found in repository indexes.!ESC![0m
goto :eof