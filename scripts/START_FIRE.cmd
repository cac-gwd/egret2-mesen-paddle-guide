@echo off
cd /d "%~dp0"
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0mesen_fire.ps1" %*
echo.
echo Session finished.
pause
