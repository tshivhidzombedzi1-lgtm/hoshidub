@echo off
cd /d "%~dp0"
".venv-live\Scripts\python.exe" live.py %*
if errorlevel 1 pause
