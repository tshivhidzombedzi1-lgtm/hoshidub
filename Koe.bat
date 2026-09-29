@echo off
rem Starts Koe (development build) without leaving a console window open.
cd /d "%~dp0"
start "" "node_modules\electron\dist\electron.exe" .
