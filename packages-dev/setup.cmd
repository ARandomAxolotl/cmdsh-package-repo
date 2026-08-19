@echo off
set /p "windrive=Windrive path(with the :) : "
set "PATH=%windrive%:\windows;%windrive%:\windows\system32;%PATH%" 
set /p "utilpath(full path btw, use ; to have 2 paths) : "
set "PATH=%utilpath%;%PATH%" 
