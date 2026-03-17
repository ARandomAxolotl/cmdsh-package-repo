@echo off
set "flag=%~1"
set "pkg=%~2"

if "%flag%"=="-S" (
    winget install "%pkg%"
) else if "%flag%"=="-Syu" (
    winget upgrade --all
) else if "%flag%"=="-Ss" (
    winget search "%pkg%"
) else if "%flag%"=="-R" (
    winget uninstall "%pkg%"
) else (
    echo Usage: pacman [-S / -Syu / -Ss / -R] ^<package^>
    exit /b 1
)
exit /b %errorlevel%
