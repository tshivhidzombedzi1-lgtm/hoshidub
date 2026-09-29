@echo off
rem Moves Hoshidub's engine and models out of Claude's private (virtualised) AppData folder into the real
rem %LOCALAPPDATA%\Hoshidub, where the installed app looks. Must be started by Explorer, not from inside Claude.
set "SRC=%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Local\Hoshidub"
set "DST=%LOCALAPPDATA%\Hoshidub"
set "LOG=%USERPROFILE%\anime-dub\fix-hoshidub-location.log"
echo started %date% %time% > "%LOG%"
if not exist "%DST%" mkdir "%DST%"
if exist "%DST%\runtime.download" rmdir /s /q "%DST%\runtime.download"
for %%F in (runtime models) do (
  if exist "%SRC%\%%F" (
    if not exist "%DST%\%%F" (
      move "%SRC%\%%F" "%DST%\%%F" >> "%LOG%" 2>&1
    ) else (
      echo skipped %%F: already exists in %DST% >> "%LOG%"
    )
  )
)
echo --- real %DST% --- >> "%LOG%"
dir /b "%DST%" >> "%LOG%"
echo --- runtime\python.exe --- >> "%LOG%"
if exist "%DST%\runtime\python.exe" (echo present >> "%LOG%") else (echo MISSING >> "%LOG%")
echo --- models --- >> "%LOG%"
dir /b "%DST%\models" >> "%LOG%" 2>&1
echo done >> "%LOG%"
