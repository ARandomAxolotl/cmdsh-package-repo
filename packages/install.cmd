@echo off
set "install_path=%1"
if "%1" == "" (
	set "install_path=."
	echo Installing to this dir.
	)
if not exist cmdSH.cmd (
	echo Downloaing cmdSH...
	curl -sL https://raw.githubusercontent.com/ARandomAxolotl/cmdSH/refs/heads/main/cmdsh.cmd --output cmdSH.cmd
	echo Configuring cmdSH...
	call cmdSH.cmd %install_path% --i-want-to-create-config-here --installer
	)
if not exist Functions ( mkdir Functions )
cd Functions
echo Downloading base packages...
curl -sL https://raw.githubusercontent.com/ARandomAxolotl/cmdsh-package-repo/refs/heads/main/packages/func.cmd --output func.cmd
echo Configuring func...
call func.cmd update
curl -sL https://raw.githubusercontent.com/ARandomAxolotl/cmdsh-package-repo/refs/heads/main/packages/scmdc.cmd --output scmdc.cmd
choice /M "Base packages installed, do you want to install other non-essensial packages?"
if %errorlevel% == 1 ( 
	call func install man
	call func install clear
	) else echo bye!