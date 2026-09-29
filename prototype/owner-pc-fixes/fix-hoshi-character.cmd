@echo off
rem Copies Hoshi's personality file into the installed app (the 0.1.0 installer left it out). Start through Explorer.
set "DST=%LOCALAPPDATA%\Programs\koe\resources\engine\character"
if not exist "%DST%" mkdir "%DST%"
copy /y "%USERPROFILE%\anime-dub\koe\engine\character\hoshi.yaml" "%DST%\hoshi.yaml" > "%USERPROFILE%\anime-dub\fix-hoshi-character.log" 2>&1
if exist "%DST%\hoshi.yaml" (echo present >> "%USERPROFILE%\anime-dub\fix-hoshi-character.log") else (echo MISSING >> "%USERPROFILE%\anime-dub\fix-hoshi-character.log")
