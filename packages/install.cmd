@echo off
set "install_path=%1"
if "%1" == "" (
	set "install_path=%CD%"
	echo Installing to this dir.
	)
if not exist cmdSH.cmd (
	echo Downloaing cmdSH...
	curl -sL https://raw.githubusercontent.com/ARandomAxolotl/cmdSH/refs/heads/main/cmdsh.cmd --output cmdSH.cmd
	echo Configuring cmdSH...
	call cmdSH.cmd %install_path% --i-want-to-create-config-here --installer
	)
(
	echo [WARNING] : If you have problem with the .cmd files, make sure to open it in notepad++, change the EOL from LF to CRLF.
	echo Git just too "helpful" to convert them from CRLF to LF
) > READMEFIRST.txt
if not exist Functions ( mkdir Functions )
cd Functions
echo Downloading base packages...
curl -sL https://raw.githubusercontent.com/ARandomAxolotl/cmdsh-package-repo/refs/heads/main/packages/func.cmd --output func.cmd
curl -sL https://raw.githubusercontent.com/ARandomAxolotl/cmdsh-package-repo/refs/heads/main/packages/scmdc.cmd --output scmdc.cmd