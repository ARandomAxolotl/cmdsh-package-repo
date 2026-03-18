@echo off
if "%1" == "" echo Specify a file!
if exist "%1" ( call cat -n %1 | more ) else ( echo File not exist! )