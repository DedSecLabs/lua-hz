<div align="center">

# LuaHZ

<p align="center">
  <img src="assets/branding/luahz-logo.png" alt="LuaHZ logo" width="160">
</p>

<p align="center">
  <a href="https://github.com/DedSecLabs/luahz/releases/tag/v0.4.1"><img src="https://img.shields.io/badge/Release-0.4.1-2563eb" alt="release 0.4.1"></a>
  <img src="https://img.shields.io/badge/Platform-SA--MP-ff8000" alt="platform SA-MP">
  <a href="https://github.com/DedSecLabs/luahz/actions/workflows/release.yml"><img src="https://img.shields.io/github/actions/workflow/status/DedSecLabs/luahz/release.yml?branch=main&label=Build&color=22c55e" alt="build status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-64748b" alt="license MIT"></a>
</p>

<p align="center">
  <b>A modern HUD and quality-of-life toolkit for Horizon Roleplay.</b>
</p>

<br>

<p align="center">
  <img width="1024" height="410" alt="LuaHZ in Horizon Roleplay" src="docs/images/readme-banner.png">
</p>

It activates only on `samp.hzgaming.net:7777` / `213.32.6.232:7777`. The same SA-MP installation can still join other servers.

[Download](https://github.com/DedSecLabs/luahz/releases/latest) · [Install](#install) · [Controls](#controls) · [Features](#features) · [Development](#development)

</div>

---

## Install

Download **[LuaHZ-0.4.1-player.zip](https://github.com/DedSecLabs/luahz/releases/download/v0.4.1/LuaHZ-0.4.1-player.zip)**.

### 1. Prepare the game and install prerequisites

Start with **GTA San Andreas 1.0 US** and either the classic **SA-MP 0.3.7 R5** browser or the optional open.mp launcher. Connect to Horizon once before adding mods.

Close **GTA and both multiplayer launchers** before copying files. Your **GTA folder** is the folder that contains `gta_sa.exe`.

Install the following prerequisites **in order**, with GTA and both multiplayer launchers closed. Use the named **32-bit (x86)** versions even on 64-bit Windows. Open each ZIP and copy its runtime files to the destination below. Keep the complete supplied libraries.

| Download — tested version | Where it goes |
|---|---|
| **1. Multiplayer launcher** — [SA-MP 0.3.7 R5](https://hzgaming.net/fullpage.php?id=download), choose `R5-2-MP`; or [open.mp launcher 1.6.1](https://open.mp/downloads/launcher). | Install SA-MP into your **GTA folder**; `samp.exe` and `samp.dll` should sit beside `gta_sa.exe`. For open.mp, point the launcher at that same folder and select the verified R5 client. |
| **2. CLEO 4.4.4 + ASI loader** — [Download](https://github.com/cleolibrary/CLEO4/releases/download/v4.4.4/CLEO4.zip) | Follow the ZIP's README. Use its supplied **Silent's ASI Loader 1.2** (`vorbisFile.dll` and `vorbisHooked.dll`) in your **GTA folder**. |
| **3. SilentPatchSA 1.1 Build 34.1** — [Official release](https://github.com/CookiePLMonster/SilentPatch/releases/tag/1.1-BUILD34.1-SA) | Download `SilentPatchSA.zip`. Put `SilentPatchSA.asi` and `SilentPatchSA.ini` beside `gta_sa.exe`. Fixes the game's intermittent streaming freeze. Use the [tested configuration](docs/INSTALLATION.md#silentpatch-configuration). |
| **4. MoonLoader 0.26.5-beta** — [Download](https://blast.hk/moonloader/download.php?archive) | Extract the runtime into your **GTA folder**. Keep `MoonLoader.asi`, the supplied DLLs, and the complete `moonloader/lib` folder. |
| **5. SAMPFUNCS 5.7.1 rel.25, R5 build** — [Download](https://www.blast.hk/attachments/255877/) | Put `SAMPFUNCS.asi` in your **GTA folder**. Use the **R5** build. |
| **6. mimgui 1.7.0** — [Download](https://github.com/THE-FYP/mimgui/releases/download/v1.7.0/mimgui-v1.7.0.zip) | Merge its library into **`moonloader/lib`**. `moonloader/lib/mimgui/init.lua` and `mimgui/cimguidx9.dll` should exist. |

**Using open.mp:** Its supported native client is build 6 and it supplies the verified SA-MP R5 client. The LuaHZ prerequisites above still apply. F9 opens the open.mp browser; use `/luahz` to assign F12 or another free LuaHZ settings shortcut. Existing preferences are preserved. See [open.mp setup and QA scope](docs/OPENMP_QA.md).

On **Linux/Wine**, install the prerequisites inside the **same Wine prefix** as this game copy. If Windows asks for missing DirectX or Visual C++ files, use Microsoft's [DirectX June 2010 package](https://www.microsoft.com/en-us/download/details.aspx?id=8109) and [Visual C++ x86 runtime](https://aka.ms/vc14/vc_redist.x86.exe).

### 2. Add LuaHZ

Close GTA and both multiplayer launchers. Extract the player ZIP outside the GTA folder.

**Windows:** from the extracted folder, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 "C:\Games\GTA San Andreas"
```

For an existing LuaHZ installation, add `-Upgrade`.

**Linux/Wine:** from the extracted folder, run:

```sh
bash install.sh "/path/to/GTA San Andreas"
```

For an existing LuaHZ installation, add `--upgrade`. The path must contain `gta_sa.exe`.

Both installers verify the payload and prerequisites, preserve preferences and saved locations, and print a recovery command. Keep the backup until the new build works. The exact 0.4.1 player archive passed owner QA on Windows 11 with both launchers. Linux/Wine owner gameplay QA covers the previous 0.4.0 release. See the [installation guide](docs/INSTALLATION.md#player-installation-and-upgrade).

### 3. Join Horizon Roleplay

Add `samp.hzgaming.net:7777` in the SA-MP browser and connect. A LuaHZ notice appears at the **bottom right**.

## Features

| Area | What LuaHZ adds |
|---|---|
| HUD | Player information, labeled stamina and oxygen, vehicle speed and health, and matching notices |
| Quickmap | Saved Horizon locations and a configurable map |
| Character Status | Skin portrait, live player information, server statistics and licenses |
| Controls | Editable shortcuts, separate normal bindings and command combos, smart vehicle locking, and cruise control |
| Performance | FPS limits for different game contexts |
| Vehicle | Controls, locks, storage, tracking and trunk balance in a compact K menu |
| Quick Actions | Navigation, skills, job locations/help and actions for your current jobs |
| Server | Searchable families and online members, rules, server settings, useful links and version observations |
| Commands | Separate Horizon server help and LuaHZ command references |
| Horizon helpers | Offer handling and tracking tools using ordinary server commands |
| Visuals | Custom loading artwork, HUD fonts, and high-resolution map and radar graphics |

## Controls

| Control | Action |
|---|---|
| **F9** (classic default) or `/luahz` | Open settings |
| **M** | Open Quickmap |
| **I** | Open Character Status |
| **U** or `/luahzactions` | Open character Quick Actions |
| **K** or `/luahzvehicle` | Open Vehicle; hold **Alt** to click while it stays visible |
| **X** | Toggle cruise control at your current speed |
| **Numpad + / −** or **= / −** | Raise or lower the cruise target by 1 mph |
| **Numpad 1 / 2 / 3** | Cruise at **50 / 80 / 120 mph** |

> Change shortcuts and preset speeds in **LuaHZ settings (`/luahz`) → Keybinds → Normal keybinds**. Cruise works while you drive a road vehicle. Brake, or press **X** again, to cancel.

New screenshots show development build **0.4.0-rc.5**. Unchanged map/HUD/menu images are retained from earlier captures.

### Settings

Configure the HUD and interface with `/luahz` or your settings shortcut.

<img src="docs/images/gallery-v03/settings-hud.png" alt="Settings" width="720"><br>

**Automation**

<img src="docs/images/gallery-v03/automation.png" alt="Automation" width="720"><br>

**Performance**

<img src="docs/images/gallery-v03/performance.png" alt="Performance" width="720"><br>

**Interface settings**

<img src="docs/images/gallery-v03/interface-settings.png" alt="Interface settings" width="720"><br>

**Changelog**

<img src="docs/images/gallery-v04/changelog.png" alt="LuaHZ changelog" width="720"><br>

### Keybinds

Normal shortcuts and command combos have separate tabs. Smart vehicle locking tries the other vehicle type only after a recognized “not nearby” response.

<img src="docs/images/gallery-v04/normal-keybinds.png" alt="Keybinds" width="720"><br>

### Vehicle menu

Press **K** for a compact panel on the right. Trunk opens on foot; Controls opens inside a vehicle. Keep moving or driving while it stays visible; hold **Alt** to click and release it for mouse/camera control. **K** or **Escape** closes it.

**Controls** use ordinary server commands for engine, lights, window, hood, trunk and locks. Engine, lights, window and hood require the driver; trunk and locks also work nearby on foot. Availability still depends on the server and vehicle.

<img src="docs/images/gallery-v04/vehicle-controls.png" alt="Vehicle controls" width="433"><br>

**Trunk** opens/closes the nearby trunk and shows **Trunk balance** on foot. Menu balance requests stay silent; typing `/trunkbalance` yourself keeps normal chat output.

<img src="docs/images/gallery-v04/vehicle-trunk-balance.png" alt="Trunk balance viewer" width="433"><br>

**My vehicles** opens storage or starts/stops tracking. Choose the vehicle in the server menu; check Spawned/Stored status before confirming. Stored vehicles need spawning before tracking.

<img src="docs/images/gallery-v04/vehicle-my-vehicles.png" alt="Vehicle storage and tracking" width="433"><br>

### Quick Actions

Press U for navigation, skills, job locations and help, plus actions matched to your current jobs. Detective tools appear for detectives. Some actions open a form for a player, price or choice; the server checks requirements.

<img src="docs/images/gallery-v04/quick-actions.png" alt="Quick Actions" width="720"><br>

### Find player

Select an online name or ID. The server checks detective-job access.

<img src="docs/images/gallery-v03/find-player.png" alt="Find player" width="720"><br>

### Server: Families

Search the complete family list, including entries that scroll out of game chat.

<img src="docs/images/gallery-v03/server-families.png" alt="Server: Families" width="720"><br>

### Server: Members

Browse online family members with their rank numbers and names.

<img src="docs/images/gallery-v03/server-members.png" alt="Server: Members" width="720"><br>

### Server: Rules

<img src="docs/images/gallery-v03/server-rules.png" alt="Server rules" width="720"><br>

### Server: Settings

<img src="docs/images/gallery-v03/server-settings.png" alt="Server settings snapshot" width="720"><br>

### Server: Links

**Server links**

<img src="docs/images/gallery-v03/server-links.png" alt="Server links" width="720"><br>

### Server: Status

**Server status**

<img src="docs/images/gallery-v04/server-status.png" alt="Server status" width="720"><br>

### Commands

Browse server help in one tab and LuaHZ commands in another.

<img src="docs/images/gallery-v03/server-commands.png" alt="Commands" width="720"><br>

**LuaHZ command reference**

<img src="docs/images/gallery-v04/mod-commands.png" alt="LuaHZ command reference" width="720"><br>

### Character Status

Press I for Character, Work, Finances, Health, Inventory and Licenses tabs.

<img src="docs/images/gallery-v04/character.png" alt="Character Status" width="720"><br>

**Work**

<img src="docs/images/gallery-v04/character-work.png" alt="Character work" width="720"><br>

**Finances**

<img src="docs/images/gallery-v04/character-finances.png" alt="Character finances" width="720"><br>

**Health**

<img src="docs/images/gallery-v04/character-health.png" alt="Character health" width="720"><br>

**Inventory**

<img src="docs/images/gallery-v04/character-inventory.png" alt="Character inventory" width="720"><br>

### Licenses

View the server-received Driver's, Pilot and Boating license statuses; Refresh requests a new snapshot.

<img src="docs/images/gallery-v04/character-licenses.png" alt="Character licenses" width="720"><br>

### Maps

Quickmap with saved locations. Press **M** or **Escape** to close it.

<img src="docs/images/quickmap.jpg" alt="Quickmap with saved locations" width="720"><br>

**Quickmap settings**

<img src="docs/images/gallery-v03/settings-quickmap.png" alt="Quickmap settings" width="720"><br>

High-resolution game map and map blips with saved locations.

<img src="docs/images/sa-mp-057.png" alt="Game map and map blips with saved locations" width="720"><br>

High-resolution radar map and map blips.

<img src="docs/images/minimap_776_canvas.png" alt="Radar map and map blips"><br>

### High-resolution player HUD

High-resolution HUD fonts and weapon icons keep the time, health, armor and cash readable.

<img src="docs/images/gallery-v04/player-hud.png" alt="High-resolution player HUD"><br>

### Vehicle HUD

Vehicle name, speed and health, Personal/Family ownership badges, and readable Doors, Engine, Lights and Window states. Unknown states use neutral icons.

<img src="docs/images/gallery-v04/vehicle-personal.png" alt="Personal vehicle dashboard"><br>
<img src="docs/images/gallery-v04/vehicle-family.png" alt="Family vehicle dashboard"><br>

### Stamina and oxygen

Labeled bars share the same width as LuaHZ notices. Notices stack above active HUD panels.

<img src="docs/images/gallery-v03/stamina.png" alt="Labeled stamina bar"><br>
<img src="docs/images/gallery-v03/oxygen.png" alt="Labeled oxygen bar"><br>

Server settings are a snapshot; they are separate from LuaHZ preferences. Version observations are informational and do not automatically disable features.

## Other servers
On any other server, LuaHZ menus, HUD, and custom visuals stay inactive. Original game and plugin files remain stock on disk.

## Development
Source checks need **Python 3.11+**, **LuaJIT 2.1**, and **GCC**:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python tools/check.py --luajit /path/to/luajit
```

Build and deploy steps are in [development](docs/DEVELOPMENT.md). GitHub's automatic source ZIP is this repository, not the player download.

**0.4.1 — Launcher Choice** includes owner-tested Windows support for open.mp 1.6.1 with SA-MP R5: LuaHZ loading artwork/bar and browser/menu coexistence. Classic launcher choice and the F9 default are retained. See [changes](docs/releases/0.4.1.md) and [open.mp QA](docs/OPENMP_QA.md), including the independently reproduced foreign-server black-splash limitation. The exact final 0.4.1 archive passed Windows 11 owner QA with both launchers. Source/build verification is recorded separately; Linux/Wine owner gameplay QA covers 0.4.0.

## Documentation

| Guide | Purpose |
|---|---|
| [Installation](docs/INSTALLATION.md) | Prerequisite layout and troubleshooting |
| [Recovery](docs/RECOVERY.md) | Restore a previous installation |

## License and acknowledgments

Original LuaHZ code is [MIT licensed](LICENSE). The mimgui adapter and Lucide icons retain their upstream notices. External software and artwork retain their own terms. See [third-party notices](THIRD_PARTY.md).

LuaHZ is an independent project informed by the visible LunaHZ feature baseline. No affiliation with Horizon Gaming, Rockstar Games, SA-MP, or the prerequisite authors is implied.

## Support

If you find this project or any of my open-source work helpful, consider supporting future development:

- 💖 [Sponsor on GitHub](https://github.com/sponsors/amir0ff)
- ☕ [Buy me a coffee on Ko-fi](https://ko-fi.com/amir0ff)
