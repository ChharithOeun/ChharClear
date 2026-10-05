# ChharClear

```
     🔥🔥🔥   C H H A R C L E A R   🔥🔥🔥
     ────────────────────────────────────────
     FFXI player utility belt
     log cleaner  •  dump purge  •  wiki mirror
     ────────────────────────────────────────
```

[![License: MIT](https://img.shields.io/badge/License-MIT-cyan.svg?style=for-the-badge)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows-ff6b35?style=for-the-badge)]()
[![PowerShell: 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-ffd700?style=for-the-badge)]()
[![Dependencies: wget](https://img.shields.io/badge/wget-auto%20installed-00ffff?style=for-the-badge)]()

**Double-click utilities for FFXI players: wipe local chat logs, nuke crash dumps, mirror your private-server wiki for offline use.**

Server-agnostic — works with Horizon XI, Phoenix XI, CatsEye XI, retail, and anything else that uses the standard FFXI client install.

---

## Tools

### 🧹 Clear logs & crash dumps

**`CLEAR-LOGS.bat`** — menu-driven cleaner for:

- FFXI chat logs (`Documents\My Games\FINAL FANTASY XI\USER\<PlayerID>\LOG\`)
- Ashita logs (auto-detects Horizon / Phoenix / standard Ashita paths)
- Crash dumps (`%LOCALAPPDATA%\CrashDumps\`, Horizon crashes/, Phoenix crashes/, more)

Options: dry run, safe clear (backs up first), force clear (no backup). Only touches `.dmp`, `.mdmp`, `.hdmp`, `.log` — nothing destructive to settings or saves.

### 📚 Offline wiki mirror

**`MIRROR-WIKI.bat`** — browsable offline mirror of any FFXI MediaWiki. Built-in knowledge of:

- Phoenix XI wiki
- Horizon XI wiki
- CatsEye XI wiki
- BG-Wiki

One-click **ALL FOUR** mode mirrors every wiki in parallel. Smart-refresh via wget's timestamping so weekly re-runs only pull changed pages.

**Hardened config:**
- Depth cap, 2GB quota per wiki (no bloat)
- Rejects MediaWiki noise (`?action=`, `?oldid=`, `?printable=`, `User:`, `Talk:`, `Special:`, etc.)
- Polite 800KB/s rate limit, random wait between requests
- Auto-installs wget to a user-writable location (no race on parallel runs)

### ⏰ Scheduler

**`SCHEDULE-MIRRORS.bat`** — install weekly Windows Task Scheduler jobs so your mirrors stay fresh without you thinking about them. Perfect for when a private server's wiki goes down (Horizon's did for days in September 2026 — ChharClear's whole origin story).

### 🔍 Diagnostic

**`DIAGNOSE-MIRRORS.bat`** — if a mirror seems stuck or runs too long, this reports which wget processes are alive, where they're writing, folder sizes, how long since the last file was written, and (critically) a URL-pattern breakdown that flags namespace traps.

---

## Install

1. Clone or download this repo somewhere user-writable (not Program Files)
2. **Double-click `INSTALL-WGET.ps1`** once — bootstraps the wget binary that `MIRROR-WIKI` depends on
3. Use any of the tools above

For auto-running mirrors on a schedule: double-click `RELAUNCH-MIRRORS.bat` and it installs wget + schedules all four wikis for tomorrow 4am (default; configurable).

---

## Default paths

- **Mirror destination:** `T:\WikiMirrors\{Phoenix,Horizon,CatsEyeXI,BGWiki}` — change via `-RootPath` or by editing the script
- **wget binary:** `%LOCALAPPDATA%\Chharizard-LAC\tools\wget.exe` — user-writable, shared across all scheduled tasks

---

## Why this exists

Private servers come and go. When Horizon XI's wiki went offline for days without warning in September 2026, half the item/mission references the community depends on just disappeared. ChharClear mirrors your wikis before they vanish, cleans up the log/dump debris that FFXI leaves behind, and generally keeps your FFXI machine tidy.

---

## Related

- 🔥 [**ChharLAC**](https://github.com/ChharithOeun/ChharLAC) — LuAshitaCast profiles for all 22 jobs (Horizon / Phoenix / retail)
- 🔥 [**reChhar**](https://github.com/ChharithOeun/reChhar) — Ashita port of React (auto-face-away during gaze attacks)
- 🔥 [**Chharizard**](https://github.com/ChharithOeun/Chharizard) — the parent FFXI toolkit

---

## License

MIT. Use freely, modify freely, no warranty.
