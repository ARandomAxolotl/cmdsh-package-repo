@echo off
setlocal DisableDelayedExpansion

:: -------- setup --------
pushd "%~dp0.."
set "replace_with=%CD%\sandbox"
if not exist "%CD%\.config\suspath.txt" (
    curl -sL "https://raw.githubusercontent.com/ARandomAxolotl/cmdsh-package-repo/refs/heads/main/suspath.txt" ^
        --output "%CD%\.config\suspath.txt"
)
if not exist "%CD%\Functions\sbatc.cmd" (
    (
        echo @echo off
        echo call scmdc.cmd %%* -b
    ) > "%CD%\Functions\sbatc.cmd"
)
set "suslist=%CD%\.config\suspath.txt"
popd

if /i "%~2"=="-b" (
    set "input=%~1.sbat"
    set "output=%~1.bat"
) else (
    set "input=%~1.scmd"
    set "output=%~1.cmd"
)

set /a line_num=0

(
for /f "usebackq delims=" %%A in ("%input%") do (

    set /a line_num+=1
    set "line=%%A"

    :: get first token (ignores leading spaces)
    for /f "tokens=1" %%T in ("%%A") do set "first=%%T"

    if defined first if "!first:~0,2!"=="::" (
        echo %%A
    ) else (

        :: ---- fixed path detection ----
        echo(%%A | findstr /r "[A-Za-z]:\\" >nul && (
            >&2 echo WARNING: fixed path in %input% line %line_num%: %%A
        )

        :: ---- suspicious path detection ----
        for /f "usebackq delims=" %%S in ("%suslist%") do (
            echo(%%A | findstr /i "%%S" >nul && (
                >&2 echo WARNING: suspicious path (%%S^) in %input% line %line_num%: %%A
            )
        )

        :: ---- replacement (safe for ! characters) ----
        setlocal EnableDelayedExpansion
        set "line=!line:@=%replace_with%!"
        echo(!line!
        endlocal
    )
)
) > "%output%"