@echo off
set "install_path=%~1"
if "%~1" == "" (
    set "install_path=."
    echo Installing to current directory.
) 

if not exist cmdSH.cmd (
    echo Downloading cmdSH...
    curl -sL https://raw.githubusercontent.com/ARandomAxolotl/cmdSH/refs/heads/main/cmdsh.cmd --output cmdSH.cmd
    echo Configuring cmdSH...
    call cmdSH.cmd "%install_path%" --i-want-to-create-config-here --installer
) 

if not exist Functions mkdir Functions
pushd Functions 

echo Downloading base packages...
curl -sL https://raw.githubusercontent.com/ARandomAxolotl/cmdsh-package-repo/main/packages/func.cmd --output func.cmd
echo Configuring func...
call func.cmd update
curl -sL https://raw.githubusercontent.com/ARandomAxolotl/cmdsh-package-repo/main/packages/scmdc.cmd --output scmdc.cmd
echo Configuring scmdc...
call scmdc.cmd --installer

choice /M "Base packages installed. Install non-essential packages (man, clear)?"
if %errorlevel% == 1 (
    call func install man
    call func install clear
) else (
    echo Skipping optional packages.
) 

popd
echo Installation complete!