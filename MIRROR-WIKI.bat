@echo off
REM FFXI wiki mirrorer (double-click friendly)
setlocal
cd /d "%~dp0"

echo.
echo ========================================================
echo   FFXI wiki mirrorer   ^|   Target: T:\WikiMirrors\
echo ========================================================
echo.
echo   [1] Mirror ONE wiki (menu picker)
echo   [2] Mirror ALL FOUR  (Phoenix, Horizon, CatsEyeXI, BGWiki)
echo   [3] Mirror ALL FOUR + schedule weekly auto-refresh (Sun 3am)
echo   [Q] Quit
echo.
set /p CHOICE="Choice: "

if /i "%CHOICE%"=="1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0MIRROR-WIKI.ps1"
    goto end
)
if /i "%CHOICE%"=="2" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0MIRROR-WIKI.ps1" -All
    goto end
)
if /i "%CHOICE%"=="3" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0MIRROR-WIKI.ps1" -All -ScheduleWeekly
    goto end
)
if /i "%CHOICE%"=="Q" goto end

echo Invalid choice.

:end
echo.
pause
