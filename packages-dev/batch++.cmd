@echo off

if "%~1" == "" (
  echo Input a file.
  exit /b
)

if "%~2" == "-c" (
    set "mode=1"
) else (
    set "mode=0"
)

if %mode% == 1 (
    if "%~3" == "" (
        set "out=a.out.bat"
    ) else (
        set "out=%~3"
    )
)

setlocal EnableDelayedExpansion

set "i="
set "comments=0"

for /f "usebackq delims=" %%a in ("%~1") do (
  set "i=%%a"
  call :exec
)
exit /b

:exec
if "!i:~0,2!" == "/*" (
  set "comments=1"
  exit /b
)
if "!i:~0,2!" == "*/" (
  set "comments=0"
  exit /b
)
if "!i:~0,2!" == "//" exit /b
if "%comments%" == "1" exit /b
if %mode% == 1 (
  >> "%out%" echo(!i!
  exit /b
) else (
  !i!
)
exit /b
