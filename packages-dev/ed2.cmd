@echo off

if "%~1" == "" (
	echo Input a file
	exit /b
)

set "outputfile=%~1"
set "sessionid=%RANDOM%%RANDOM%"
set "sessionconf=%sessionid%-ed2.conf"
set "openingfileid=1"
set /a filecount=1

:lckfileprepare
set "lckfile=%outputfile%.lck"

if exist %lckfile% goto :existlckfile

:prepare
set "tmpfile=%sessionid%_%outputfile%.tmp"
echo %sessionid%>"%lckfile%"

if not exist "%sessionconf%" echo %outputfile%>"%sessionconf%"
if exist "%outputfile%" ( 
  type "%outputfile%">"%tmpfile%"
) else (
  type nul>"%tmpfile%"
)

:loop
set "errlv=1"
set "i="
set /p "i=(%outputfile%): "

if "%i%"=="a" goto :append
if "%i%"=="i" goto :insert
:: append
if "%i%"=="w" goto :write
:: write, yes
if "%i%"=="e" goto :openmorefile
if "%i%"=="q" goto :exit
:: quit
if "%i%"=="rf" goto :readfile
:: read existfile
if "%i%"=="rt" goto :readtmpbuffer
:: read tmpbuffer

if "%i%"=="ct" type nul>"%tmpfile%" & set errlv=0
:: clear tmpbuffer
if "%i%"=="cf" type nul>"%outputfile%" & set errlv=0
:: clear file!!

if "%i%"=="fo" goto :openmorefile
:: open more files!
if "%i%"=="fc" call :changefile "%openingfileid%" "%sessionconf%"
:: change the file!!!
if "%i%"=="fl" type "%sessionconf%"
:: list opening file!
if "%i%"=="h"  set help=1 && goto :helpcommon
if "%i%"=="ha" goto :help
if "%i%"=="hf" set help=1 && goto :helpfile
if "%i%"=="hd" set help=1 && goto :helpdel
if "%i%"=="hr" set help=1 && goto :helpread
:: help!
set help=0
if "%errlv%"=="1" echo Unknown command: '%i%'. Type 'h' for help.

goto :loop

:append
setlocal EnableDelayedExpansion 
set "i="
set /p "i=(appending %outputfile%): "
if "!i:~0,1!"=="." (
  endlocal
  goto :loop
)
(
  echo(!i!
)>>"%tmpfile%"
goto :append

:write
type %tmpfile%>"%outputfile%"
goto :loop

:readfile
if exist "%outputfile%" (
  type "%outputfile%"
) else (
  echo File '%outputfile%' not saved/exist yet!
  echo Press 'w' to write!
)
goto :loop

:readtmpbuffer
type "%tmpfile%"
goto :loop

:exit
call :cleanup "%sessionconf%" "%sessionid%"
del "%sessionconf%"
exit /b

:existlckfile
echo Maybe another %~n0 is editing the file '%outputfile%'
echo Or %~n0 crashed while editing
echo r(recover), e(edit anyway), q(quit)
:lckfileloop
set "i="
set /p "i=(%outputfile% recovery): "
if "%i%"=="r" goto :recoverlckfile
if "%i%"=="e" goto :prepare
if "%i%"=="h" echo r(recover), e(edit anyway), q(quit)
if "%i%"=="q" exit /b
echo ?
goto :lckfileloop

:recoverlckfile
for /f "delims=" %%A in ('type "%lckfile%"') do (
    set "sessionid=%%A"
    goto :prepare
)


:openmorefile
set "i="
set /p "i=Filename :"

echo %i%>>"%sessionconf%"
set "outputfile=%i%"
set /a filecount+=1
goto :lckfileprepare

:changefile
setlocal EnableDelayedExpansion
set /a n=%~1+1
set conf=%~2
set /a i=0

for /f "delims=" %%A in ("%conf%") do (
  set /a i+=1
  if !i! equ %n% (
    set "line=%%A"
    goto :found
  )
)
:found
endlocal && set "outputfile=%line%"
set /a openingfileid=(openingfileid%%filecount)+1
goto :changefileprepare

:cleanup
setlocal EnableDelayedExpansion
set /a line=0
for /f "delims=" %%A in (%~1) do (
  set /a line+=1
  set "content=%%A"

  del "!content!.lck"
  del "%~2_!content!.tmp"
)
endlocal
exit /b

:help
:helpcommon
echo Edit commands : 
echo 'a'  : append text
echo 'i'  : insert text
echo.
echo Exit :
echo 'q'  : quit, discarding any changes
echo.
echo Write :
echo 'w'  : write buffer to disk
echo.
echo Help :
echo 'h'  : general help
echo 'ha' : show all help
echo 'hr' : read commands help
echo 'hd' : delete/clear commands help
echo 'hf' : file commands help
echo.
echo Alias :
echo 'e'  = 'fo'
echo.
if "%help%"=="1" goto :loop
:helpread
echo Read commands :
echo 'rt' : read write buffer
echo 'rf' : read file from disk
echo.
if "%help%"=="1" goto :loop
:helpdel
echo Clear/Delete commands : 
echo 'ct' : clear write buffer
echo 'cf' : clear file on disk(caution!)
echo.
if "%help%"=="1" goto :loop
:helpfile
echo Files command :
echo 'fo' : open/create a file
echo 'fc' : cycle through open files
echo 'fl' : list open files.
goto :loop

:insert
set "i="
set /p "i=Line :"
if "%i%"=="" ( 
  echo Input a line. 
  goto :loop
)
set "insertline=%i%"
call :insertprepare "%insertline%" "%tmpfile%"
goto :doinsert
:finishinsert
call :cleaninsert "%insertline%" "%tmpfile%"
type "%inserttmpbuffer%">"%tmpfile%"
del "%inserttmpbuffer%"
goto :loop

:changefileprepare
set "lckfile=%outputfile%.lck"
goto :prepare

:insertprepare
setlocal EnableDelayedExpansion

set "source=%~2"
set "target=%~2.2"
set "limit=%~1"

(
    set /a count=0
    for /f "delims=" %%A in ('type "%source%"') do (
        set /a count+=1
        if !count! LSS %limit% echo %%A
    )
) > "%target%"

endlocal && set "inserttmpbuffer=%target%"
exit /b

:doinsert
setlocal EnableDelayedExpansion && set "inserttmpbuffer=%inserttmpbuffer%" && set "crrinsertline=%insertline%"
set "i="
set /p "i=(inserting %outputfile% at line %crrinsertline%): "
set /a crrinsertline+=1
if "!i:~0,1!"=="." (
  endlocal
  goto :finishinsert
)
(
  echo(!i!
)>>"%inserttmpbuffer%"
goto :doinsert

:cleaninsert
setlocal EnableDelayedExpansion

set "source=%~2"
set "target=%~2.2"
set "limit=%~1"

(
  set /a count=0
  for /f "delims=" %%A in ('type "%source%"') do (
    set /a count+=1
    if !count! GTR %limit% (
      >>"%target%" echo(%%A
    )
  )
)
endlocal
exit /b
