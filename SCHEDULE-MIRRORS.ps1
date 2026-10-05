# Schedule (or reschedule) wiki-mirror tasks without running them now.
#
# Default: all four tasks fire at the SAME time -- tomorrow at 3:00 PM local --
# then repeat weekly on that same weekday/time. Pass -StartTime to override.
#
# Why not stagger: all four tasks are network-bound, so running them in
# parallel finishes faster than serializing (bottlenecked by the slowest
# wiki, which is BG-Wiki). CPU and T:\ disk I/O will cope fine.

param(
    [datetime]$StartTime = (Get-Date).Date.AddDays(1).AddHours(4),   # tomorrow 4am local
    [string]  $RootPath  = "T:\WikiMirrors",
    [switch]  $Remove                                                 # tear down all four tasks
)

# Prerequisite check: wget must be installed BEFORE scheduling, otherwise all
# four tasks race on the download and only one survives.
$wgetPath = Join-Path $env:LOCALAPPDATA "Chharizard-LAC\tools\wget.exe"
if (-not $Remove -and -not (Test-Path $wgetPath)) {
    Write-Host "ERROR: wget not pre-installed at $wgetPath" -ForegroundColor Red
    Write-Host "Run INSTALL-WGET.ps1 (or INSTALL-WGET.bat) first, then re-run this script." -ForegroundColor Yellow
    exit 1
}

$ErrorActionPreference = "Stop"

$WikiRegistry = @(
    @{ Name = "Phoenix";    Url = "https://wiki.phoenix-xi.com/"; Folder = "Phoenix"    }
    @{ Name = "Horizon";    Url = "https://wiki.horizonxi.com/";  Folder = "Horizon"    }
    @{ Name = "CatsEye XI"; Url = "https://wiki.catseyexi.com/";  Folder = "CatsEyeXI"  }
    @{ Name = "BG-Wiki";    Url = "https://www.bg-wiki.com/";     Folder = "BGWiki"     }
)

$mirrorScript = Join-Path $PSScriptRoot "MIRROR-WIKI.ps1"
if (-not (Test-Path $mirrorScript)) {
    Write-Host "ERROR: MIRROR-WIKI.ps1 not found next to this script." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Wiki-mirror task scheduler"               -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# Remove mode: tear everything down
# ---------------------------------------------------------------------------
if ($Remove) {
    Write-Host "Removing existing wiki-mirror tasks..." -ForegroundColor Yellow
    foreach ($w in $WikiRegistry) {
        $taskName = "ChharLAC-WikiMirror-$($w.Folder)"
        $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existing) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Host "  Removed: $taskName" -ForegroundColor Green
        } else {
            Write-Host "  (not found): $taskName" -ForegroundColor DarkGray
        }
    }
    Write-Host "Done." -ForegroundColor Cyan
    exit 0
}

# ---------------------------------------------------------------------------
# Create/update all four tasks
# ---------------------------------------------------------------------------
$weekday = $StartTime.DayOfWeek
Write-Host "First run:  $($StartTime.ToString('yyyy-MM-dd HH:mm')) local time ($weekday)" -ForegroundColor Green
Write-Host "Then every: $weekday at $($StartTime.ToString('HH:mm')) local" -ForegroundColor Green
Write-Host "Root:       $RootPath"
Write-Host ""

$installed = @()
foreach ($w in $WikiRegistry) {
    $taskName = "ChharLAC-WikiMirror-$($w.Folder)"
    $dest     = Join-Path $RootPath $w.Folder

    # Every task gets Force so a re-run just replaces whatever was there before.
    $action = New-ScheduledTaskAction `
                -Execute "powershell.exe" `
                -Argument ("-NoProfile -ExecutionPolicy Bypass -File `"$mirrorScript`" " +
                           "-WikiUrl `"$($w.Url)`" -Destination `"$dest`" -Force")

    # Weekly trigger derived from $StartTime -- Task Scheduler uses the DOW of
    # the start date to pick which weekday to repeat on.
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $weekday -At $StartTime

    $settings = New-ScheduledTaskSettingsSet `
                  -RunOnlyIfNetworkAvailable `
                  -StartWhenAvailable `
                  -AllowStartIfOnBatteries `
                  -ExecutionTimeLimit (New-TimeSpan -Hours 8)   # cap at 8h just in case

    try {
        Register-ScheduledTask -TaskName $taskName `
                               -Action $action `
                               -Trigger $trigger `
                               -Settings $settings `
                               -Description "Mirror $($w.Url) -> $dest. Managed by Chharizard-LAC." `
                               -Force | Out-Null
        Write-Host "  OK: $taskName  -> $dest" -ForegroundColor Green
        $installed += $taskName
    } catch {
        Write-Host "  FAIL: $taskName  ($_)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  $($installed.Count)/$($WikiRegistry.Count) tasks installed"
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "All four will fire SIMULTANEOUSLY at the scheduled time." -ForegroundColor Yellow
Write-Host "Expect network + T:\ activity for ~2-4 hours after kickoff."
Write-Host ""
Write-Host "To see them in Task Scheduler GUI:  taskschd.msc"
Write-Host "To list from PowerShell:            Get-ScheduledTask -TaskName 'ChharLAC-WikiMirror-*'"
Write-Host "To remove all:                      .\SCHEDULE-MIRRORS.ps1 -Remove"
Write-Host ""
