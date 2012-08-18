@echo off
setlocal
set NAME=invaders

if "%1"=="clean" goto clean

pyz80.py -I samdos2 --exportfile=%NAME%.sym %NAME%.asm
if errorlevel 1 goto end
if "%1"=="run" start %NAME%.dsk
goto end

:clean
if exist %NAME%.dsk del %NAME%.dsk %NAME%.sym

:end
endlocal
