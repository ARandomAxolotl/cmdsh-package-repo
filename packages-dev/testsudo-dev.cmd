@echo off

:: 1. Check existence
where sudo >nul 2>&1
if %errorlevel% neq 0 (
    echo NOT_INSTALLED
    exit /b 1
)

:: 2. Check status
sudo config 2>&1 | findstr /I "currently" >nul
if %errorlevel% neq 0 (
    echo DISABLED
    exit /b 2
)

echo ENABLED
exit /b 0	