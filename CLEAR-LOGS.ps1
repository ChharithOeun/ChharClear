# Chharizard-LAC log cleaner
#
# What this clears:
#   1. FFXI client chat logs -- Documents\My Games\FINAL FANTASY XI\USER\<PlayerID>\LOG\
#      (binary rotating log files where /echo and print() output ends up)
#   2. Ashita log files      -- <Ashita>\logs\*.log
#      (LAC diagnostic output + addon load traces)
#
# What this does NOT touch:
#   - macro palette (.macro files under USER\<PlayerID>\MACRO\)
#   - keybinds, character settings, item cache
#   - your LAC profiles (they live under config/addons/luashitacast/)
#
# Everything is backed up to <folder>\_backup_<timestamp>\ first. Use -Force
# to skip the backup if you're sure.

param(
    [string]$AshitaPath = "",           # optional: e.g. C:\Ashita\v4
    [switch]$Force,                     # skip backup step
    [switch]$WhatIf                      # dry run -- list what would be cleared
)

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

function Show-Header($title) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host $title -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

# --------------------------------------------------------------------------
# 1. Find FFXI chat log directories
# --------------------------------------------------------------------------
Show-Header "1. FFXI CLIENT CHAT LOGS"

$ffxiRoot = Join-Path $env:USERPROFILE "Documents\My Games\FINAL FANTASY XI\USER"
if (-not (Test-Path $ffxiRoot)) {
    Write-Host "FFXI USER folder not found at $ffxiRoot" -ForegroundColor Yellow
    Write-Host "(This is normal if you've never launched retail FFXI on this machine.)"
} else {
    # Every character has its own numbered subfolder
    $playerDirs = Get-ChildItem $ffxiRoot -Directory
    if ($playerDirs.Count -eq 0) {
        Write-Host "No player folders found." -ForegroundColor Yellow
    } else {
        foreach ($p in $playerDirs) {
            $logDir = Join-Path $p.FullName "LOG"
            if (Test-Path $logDir) {
                $files = Get-ChildItem $logDir -File -ErrorAction SilentlyContinue
                if ($files.Count -eq 0) {
                    Write-Host "  $($p.Name)\LOG: already empty" -ForegroundColor Gray
                    continue
                }
                $totalKb = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1KB, 1)
                Write-Host "  Player $($p.Name): $($files.Count) log file(s), $totalKb KB" -ForegroundColor White

                if ($WhatIf) {
                    Write-Host "    [WhatIf] would remove: $($files.Name -join ', ')" -ForegroundColor DarkGray
                    continue
                }

                if (-not $Force) {
                    $backupDir = Join-Path $p.FullName "_backup_LOG_$stamp"
                    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
                    $files | Copy-Item -Destination $backupDir
                    Write-Host "    Backed up to $backupDir" -ForegroundColor Green
                }
                $files | Remove-Item -Force
                Write-Host "    Cleared." -ForegroundColor Green
            }
        }
    }
}

# --------------------------------------------------------------------------
# 2. Ashita log files
# --------------------------------------------------------------------------
Show-Header "2. ASHITA LOGS"

if (-not $AshitaPath) {
    # Try common install paths (Horizon, Phoenix, generic Ashita, retail POL layouts)
    $candidates = @(
        "$env:LOCALAPPDATA\Horizon\HorizonXI\Game",
        "$env:LOCALAPPDATA\Phoenix\PhoenixXI\Game",
        "$env:LOCALAPPDATA\PhoenixXI\Game",
        "$env:LOCALAPPDATA\Phoenix-XI\Game",
        "C:\Ashita\v4",
        "C:\Ashita",
        "$env:USERPROFILE\Ashita",
        "$env:USERPROFILE\Desktop\Ashita",
        "$env:USERPROFILE\Documents\Ashita"
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "logs")) {
            $AshitaPath = $c
            Write-Host "Auto-detected Ashita at: $c" -ForegroundColor Green
            break
        }
    }
}

if (-not $AshitaPath -or -not (Test-Path (Join-Path $AshitaPath "logs"))) {
    Write-Host "Could not find Ashita\logs. Re-run with -AshitaPath <path>" -ForegroundColor Yellow
} else {
    $ashLogs = Get-ChildItem (Join-Path $AshitaPath "logs") -File -Filter "*.log" -ErrorAction SilentlyContinue
    if ($ashLogs.Count -eq 0) {
        Write-Host "  Ashita logs: already empty" -ForegroundColor Gray
    } else {
        $totalKb = [math]::Round(($ashLogs | Measure-Object Length -Sum).Sum / 1KB, 1)
        Write-Host "  Ashita: $($ashLogs.Count) log file(s), $totalKb KB" -ForegroundColor White

        if ($WhatIf) {
            Write-Host "    [WhatIf] would remove: $($ashLogs.Name -join ', ')" -ForegroundColor DarkGray
        } else {
            if (-not $Force) {
                $backupDir = Join-Path $AshitaPath "logs\_backup_$stamp"
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
                $ashLogs | Copy-Item -Destination $backupDir
                Write-Host "    Backed up to $backupDir" -ForegroundColor Green
            }
            $ashLogs | Remove-Item -Force
            Write-Host "    Cleared." -ForegroundColor Green
        }
    }
}

# --------------------------------------------------------------------------
# 3. Crash dumps (.dmp)
# --------------------------------------------------------------------------
Show-Header "3. CRASH DUMPS"

# Well-known crash-dump locations for FFXI-related processes
$dumpTargets = @(
    "$env:LOCALAPPDATA\CrashDumps",                                    # Windows Error Reporting default
    # Horizon
    "$env:LOCALAPPDATA\Horizon\HorizonXI\Game",
    "$env:LOCALAPPDATA\Horizon\HorizonXI\Game\crashes",
    "$env:LOCALAPPDATA\Horizon\HorizonXI\Game\logs",
    # Phoenix
    "$env:LOCALAPPDATA\Phoenix\PhoenixXI\Game",
    "$env:LOCALAPPDATA\Phoenix\PhoenixXI\Game\crashes",
    "$env:LOCALAPPDATA\Phoenix\PhoenixXI\Game\logs",
    "$env:LOCALAPPDATA\PhoenixXI\Game",
    "$env:LOCALAPPDATA\Phoenix-XI\Game"
)
# Add Ashita path if we found it above
if ($AshitaPath) {
    $dumpTargets += (Join-Path $AshitaPath "")               # root
    $dumpTargets += (Join-Path $AshitaPath "logs")
    $dumpTargets += (Join-Path $AshitaPath "crashes")
}
# And Steam FFXI POL install (retail path)
$dumpTargets += "$env:PROGRAMFILES(X86)\Steam\steamapps\common\FFXINA\SquareEnix\PlayOnlineViewer"
$dumpTargets += "$env:PROGRAMFILES(X86)\PlayOnline\SquareEnix\PlayOnlineViewer"

$anyDumps = $false
foreach ($t in $dumpTargets | Select-Object -Unique) {
    if (-not (Test-Path $t)) { continue }
    # Only grab .dmp / .mdmp / .hdmp files; leave everything else alone
    $dumps = Get-ChildItem $t -File -Include *.dmp,*.mdmp,*.hdmp -ErrorAction SilentlyContinue
    if ($dumps.Count -eq 0) { continue }
    $anyDumps = $true
    $totalMb = [math]::Round(($dumps | Measure-Object Length -Sum).Sum / 1MB, 1)
    Write-Host "  $t : $($dumps.Count) dump(s), $totalMb MB" -ForegroundColor White

    if ($WhatIf) {
        foreach ($d in $dumps) { Write-Host "    [WhatIf] would remove: $($d.Name) ($([math]::Round($d.Length/1MB, 1)) MB)" -ForegroundColor DarkGray }
        continue
    }

    if (-not $Force) {
        # Backups for large dumps just eat disk. Skip backup for dumps by default;
        # user can copy them manually if they want to debug a crash.
        Write-Host "    (no backup taken for .dmp files -- copy any you want to keep first)" -ForegroundColor DarkGray
    }
    $dumps | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "    Cleared." -ForegroundColor Green
}
if (-not $anyDumps) {
    Write-Host "  No crash dumps found in any known location." -ForegroundColor Gray
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
Write-Host ""
Write-Host "Reminders:" -ForegroundColor Yellow
Write-Host "  * Run this BEFORE launching FFXI, not while playing (open files block delete)" -ForegroundColor Yellow
Write-Host "  * FFXI regenerates log files on next launch"
Write-Host "  * If you use Chharbar or another chat logger, clear its logs too"
Write-Host "  * ScreenShots/ folder is NOT touched -- clean those separately"
Write-Host "  * Dumps are NOT backed up by default -- copy any you want to keep first"
Write-Host ""
