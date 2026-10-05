@echo off
REM Schedule the wiki-mirror tasks without running them now.
setlocal
cd /d "%~dp0"

echo.
echo ========================================================
echo   Wiki-mirror task scheduler
echo ========================================================
echo.
echo   [1] Install for tomorrow 3pm local (then weekly on same day/time)
echo   [2] Install at custom date/time
echo   [3] Remove all four scheduled tasks
echo   [Q] Quit
echo.
set /p CHOICE="Choice: "

if /i "%CHOICE%"=="1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SCHEDULE-MIRRORS.ps1"
    goto end
)
if /i "%CHOICE%"=="2" (
    set /p "WHEN=Enter start date/time (YYYY-MM-DD HH:MM, 24-hour local): "
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SCHEDULE-MIRRORS.ps1" -StartTime "%WHEN%"
    goto end
)
if /i "%CHOICE%"=="3" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SCHEDULE-MIRRORS.ps1" -Remove
    goto end
)
if /i "%CHOICE%"=="Q" goto end

echo Invalid choice.

:end
echo.
pause
