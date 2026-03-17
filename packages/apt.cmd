@echo off
set "cmd=%~1"
set "pkg=%~2"

if "%cmd%"=="install" (
    winget install "%pkg%"
) else if "%cmd%"=="update" (
    winget upgrade
) else if "%cmd%"=="upgrade" (
    winget upgrade "%pkg%"
) else if "%cmd%"=="search" (
    winget search "%pkg%"
) else (
    echo Usage: apt [install/update/upgrade/search] ^<package^>
    exit /b 1
)
exit /b %errorlevel%
