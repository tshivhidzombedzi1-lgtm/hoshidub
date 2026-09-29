@echo off
rem Adds the libraries Hoshi's brain needs (accelerate, bitsandbytes, psutil) to the installed Hoshidub engine,
rem copied from the developer venv (same Python 3.12). Start it through Explorer so it writes to the real AppData.
set "SRC=%USERPROFILE%\anime-dub\.venv\Lib\site-packages"
set "DST=%LOCALAPPDATA%\Hoshidub\runtime\Lib\site-packages"
set "LOG=%USERPROFILE%\anime-dub\fix-hoshi-libraries.log"
echo started %date% %time% > "%LOG%"
for %%P in (accelerate accelerate-1.15.0.dist-info bitsandbytes bitsandbytes-0.50.2.dist-info psutil psutil-7.2.2.dist-info) do (
  robocopy "%SRC%\%%P" "%DST%\%%P" /E /NFL /NDL /NJH /NJS /NP >> "%LOG%"
)
"%LOCALAPPDATA%\Hoshidub\runtime\python.exe" -c "import accelerate, bitsandbytes, psutil; print('import ok', accelerate.__version__, bitsandbytes.__version__, psutil.__version__)" >> "%LOG%" 2>&1
echo done >> "%LOG%"
