@echo off
if "%~1"=="" (
    :: Read from stdin if no file is provided
    findstr "^"
) else (
    type "%~1"
)
exit /b %errorlevel%