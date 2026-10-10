# LuaHZ base player preview — Linux/Wine

Use a separate clean classic GTA San Andreas 1.0 US copy. This prerelease keeps stock native fonts/radar/loading, excludes HD visual resources and portraits, and has no usable Quickmap background. Use the game's ESC map. Character statistics remain available without a portrait. HUD text uses the existing font fallback; final appearance needs your live test.

1. Back up your game and use an isolated Wine prefix. Confirm you can join Horizon before adding LuaHZ.
2. Install SA-MP R5 (Horizon R5-2-MP), CLEO 4.4.4 with its supplied loader, MoonLoader 0.26.5-beta, SAMPFUNCS 5.7.1 rel.25 R5 and mimgui 1.7.0 into the same game copy/prefix. Exact downloads and destinations: https://github.com/DedSecLabs/luahz#2-install-the-tested-prerequisites
3. Skip the separate SAMP.Lua download/edit step: this package includes the eight verified MIT-licensed Lua files with the material-handler adjustment already applied. Their original notices and full license are included.
4. Close GTA and the SA-MP browser. Extract this ZIP outside your game folder. In a Linux terminal, change into this extracted folder, then run:

```sh
bash install.sh "/path/to/your/clean/GTA San Andreas"
```

The path must contain gta_sa.exe. The installer verifies the tested binary hashes and required libraries, refuses an existing LuaHZ installation, and checks package hashes before writing. It preserves settings/unrelated files and backs up any replaced SAMP.Lua files. No Python/compiler or manual Lua edits are needed. If checks fail, stop and record the error rather than bypassing the guard.

5. Launch SA-MP for this game copy within its Wine prefix and join samp.hzgaming.net:7777. F9 or /luahz opens settings, I opens Character Status, X toggles cruise while driving; numpad +/− adjusts it. Verify HUD/dashboard, settings and cruise. M opens the existing Quickmap panel but its background is absent in this edition; no map functionality is advertised.
6. Exit fully, connect to another server and verify stock behavior; then return to Horizon. The owner completed this Linux/Wine check on 2026-10-09, including one post-login stall that cleared after a restart. Report a new issue with moonloader/moonloader.log, omitting personal/account information.

## Recovery

The installer prints an exact recovery command using the backup created in GTA/LuaHZ-backups. Close GTA/SA-MP and run that command to restore replaced library files and remove the installed payload. Recovery refuses files changed since installation. Your settings and unrelated files are retained. Keep the backup.

This shell installer is for Linux/Wine. Optional visual-pack installation and in-place updates are outside this prerelease; use a clean copy for this test.

## Windows

The same folder includes `install.ps1` and `restore.ps1`. Close GTA and the SA-MP browser, open PowerShell in the extracted folder, and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 "C:\path\to\GTA San Andreas"
```

The path must contain `gta_sa.exe`. The script checks the same prerequisite and payload hashes, refuses an existing LuaHZ install, backs up replaced files, and rolls back a failed copy. Recovery prints a `restore.ps1` command. No native Windows clean-install test has been run, so this script is not yet a supported Windows release.
