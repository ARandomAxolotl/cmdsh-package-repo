@echo off
set "params=%*"

if "%params%"=="" (
    dir /w /b
    exit /b %errorlevel%
) else (
    :: Use pushd to "peek", list, then return
    pushd "%params%" 2>nul
    if %errorlevel% equ 0 (
        dir /w /b
        popd
        exit /b 0
    ) else (
        echo [91mPath not found: %params%[0m
        exit /b 1
    )
)