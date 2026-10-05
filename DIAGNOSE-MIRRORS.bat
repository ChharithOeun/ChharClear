@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0DIAGNOSE-MIRRORS.ps1"
echo.
pause
