@echo off
if "%~1"=="" (
    echo Usage: touch ^<filename^>
    exit /b 1
)
:: Use type nul to create an empty file
if not exist "%~1" (
    type nul > "%~1"
) else (
    :: Update timestamp
    copy /b "%~1" +,, >nul 2>&1
)
exit /b 0