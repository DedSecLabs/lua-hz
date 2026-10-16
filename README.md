<div align="center">

# LuaHZ

<p align="center">
  <img src="assets/branding/luahz-logo.png" alt="LuaHZ logo" width="160">
</p>

<p align="center">
  <a href="https://github.com/DedSecLabs/luahz/releases/tag/v0.4.2"><img src="https://img.shields.io/badge/Release-0.4.2-2563eb" alt="release 0.4.2"></a>
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

Download **[LuaHZ-0.4.2-player.zip](https://github.com/DedSecLabs/luahz/releases/download/v0.4.2/LuaHZ-0.4.2-player.zip)**.

**0.4.2 — Loading Forward:** restores the LuaHZ artwork and centered bar with open.mp 1.7.0, adds three selectable themes, compact job actions, sharper HUD lettering and a classic-style Proper Radar Quickmap, and fixes the Changelog tab crash. Vehicle menus gain contextual shortcuts, matching dashboard states and clearer feedback. Loading compatibility with open.mp 1.6.1 and classic R5 is retained; existing server commands and configured global bindings are preserved.

### 1. Prepare the game and install prerequisites

Start with **GTA San Andreas 1.0 US** and either the classic **SA-MP 0.3.7 R5** browser or the optional open.mp launcher. Connect to Horizon once before adding mods.

Close **GTA and both multiplayer launchers** before copying files. Your **GTA folder** is the folder that contains `gta_sa.exe`.

Install the following prerequisites **in order**, with GTA and both multiplayer launchers closed. Use the named **32-bit (x86)** versions even on 64-bit Windows. Open each ZIP and copy its runtime files to the destination below. Keep the complete supplied libraries.

| Download — tested version | Where it goes |
|---|---|
| **1. Multiplayer launcher** — [SA-MP 0.3.7 R5](https://hzgaming.net/fullpage.php?id=download), choose `R5-2-MP`; or [open.mp launcher 1.7.0](https://open.mp/downloads/launcher). | Install SA-MP into your **GTA folder**; `samp.exe` and `samp.dll` should sit beside `gta_sa.exe`. For open.mp, point the launcher at that same folder and select the verified R5 client. |
| **2. CLEO 4.4.4 + ASI loader** — [Download](https://github.com/cleolibrary/CLEO4/releases/download/v4.4.4/CLEO4.zip) | Follow the ZIP's README. Use its supplied **Silent's ASI Loader 1.2** (`vorbisFile.dll` and `vorbisHooked.dll`) in your **GTA folder**. |
| **3. SilentPatchSA 1.1 Build 34.1** — [Official release](https://github.com/CookiePLMonster/SilentPatch/releases/tag/1.1-BUILD34.1-SA) | Download `SilentPatchSA.zip`. Put `SilentPatchSA.asi` and `SilentPatchSA.ini` beside `gta_sa.exe`. Fixes the game's intermittent streaming freeze. Use the [tested configuration](docs/INSTALLATION.md#silentpatch-configuration). |
| **4. MoonLoader 0.26.5-beta** — [Download](https://blast.hk/moonloader/download.php?archive) | Extract the runtime into your **GTA folder**. Keep `MoonLoader.asi`, the supplied DLLs, and the complete `moonloader/lib` folder. |
| **5. SAMPFUNCS 5.7.1 rel.25, R5 build** — [Download](https://www.blast.hk/attachments/255877/) | Put `SAMPFUNCS.asi` in your **GTA folder**. Use the **R5** build. |
| **6. mimgui 1.7.0** — [Download](https://github.com/THE-FYP/mimgui/releases/download/v1.7.0/mimgui-v1.7.0.zip) | Merge its library into **`moonloader/lib`**. `moonloader/lib/mimgui/init.lua` and `mimgui/cimguidx9.dll` should exist. |

**Using open.mp:** The tested launcher/client pairs are 1.7.0/build 7 and 1.6.1/build 6; both use the verified SA-MP R5 client. The LuaHZ prerequisites above still apply. F9 opens the open.mp browser; use `/luahz` to assign F12 or another free LuaHZ settings shortcut. Existing preferences are preserved. See [open.mp setup and QA scope](docs/OPENMP_QA.md).

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

Both installers verify the payload and prerequisites, preserve preferences and saved locations, and print a recovery command. Keep the backup until the new build works. The loading helper passed owner QA on Windows 11 with open.mp 1.7.0/build 7, open.mp 1.6.1/build 6 and classic SA-MP R5. Exact release archive acceptance is recorded separately. Linux/Wine owner gameplay QA covers the previous 0.4.0 release. See the [installation guide](docs/INSTALLATION.md#player-installation-and-upgrade).

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
| **K** or `/luahzvehicle` | Open Vehicle; use its displayed shortcuts or hold **Alt** to click |
| **X** | Toggle cruise control at your current speed |
| **Numpad + / −** or **= / −** | Raise or lower the cruise target by 1 mph |
| **Numpad 1 / 2 / 3** | Cruise at **50 / 80 / 120 mph** |

> Change shortcuts and preset speeds in **LuaHZ settings (`/luahz`) → Keybinds → Normal keybinds**. Cruise works while you drive a road vehicle. Brake, or press **X** again, to cancel.

The new **0.4.2** captures show Graphite + Ice Blue, its two alternative themes, compact job actions, Character/Server pages and vehicle interfaces. Older map/radar and stamina/oxygen illustrations remain where a new matching capture was not supplied. Screenshot text and colors are preserved exactly.

### HUD

The HUD tab controls stamina and oxygen displays and the vehicle dashboard. Configure the HUD with `/luahz`.

<img src="docs/images/gallery-v042/hud-settings.png" alt="HUD settings" width="720"><br>

High-resolution HUD fonts and weapon icons keep the time, health, armor and cash readable.

<img src="docs/images/gallery-v042/player-hud.png" alt="High-resolution player HUD"><br>

Vehicle name, speed and health, **Personal Vehicle / Family Vehicle** badges, and readable Doors, Engine, Lights and Window states. The menu and dashboard share the theme accent for On/Open/Unlocked and a readable pale tone for Off/Closed/Locked/Unknown; text and lock shapes distinguish their meanings.

<img src="docs/images/gallery-v042/vehicle-personal.png" alt="Personal vehicle dashboard"><br>
<img src="docs/images/gallery-v042/vehicle-family.png" alt="Family vehicle dashboard"><br>

Labeled stamina and oxygen bars share the same width as LuaHZ notices. Notices stack above active HUD panels.

<img src="docs/images/gallery-v03/stamina.png" alt="Labeled stamina bar"><br>
<img src="docs/images/gallery-v03/oxygen.png" alt="Labeled oxygen bar"><br>

### Quickmap

Quickmap with saved locations. Press **M** or **Escape** to close it.

<img src="docs/images/quickmap.jpg" alt="Quickmap with saved locations" width="720"><br>

Adjust map opacity and the locations and overlays shown in Quickmap.

<img src="docs/images/gallery-v042/settings-quickmap.png" alt="Quickmap settings" width="720"><br>

High-resolution game map and map blips with saved locations.

<img src="docs/images/sa-mp-057.png" alt="Game map and map blips with saved locations" width="720"><br>

High-resolution radar map and map blips.

<img src="docs/images/minimap_776_canvas.png" alt="Radar map and map blips"><br>

### Automation

Configure auto-accept limits and detective helpers.

<img src="docs/images/gallery-v042/automation.png" alt="Automation" width="720"><br>

### Keybinds

Normal shortcuts and command combos have separate tabs. Smart vehicle locking tries the other vehicle type only after a recognized “not nearby” response.

<img src="docs/images/gallery-v042/normal-keybinds.png" alt="Keybinds" width="720"><br>

<img src="docs/images/gallery-v042/command-combos.png" alt="Command combos" width="720"><br>

### Performance

Set separate FPS limits for on-foot, vehicle, swimming and boat situations.

<img src="docs/images/gallery-v042/performance.png" alt="Performance" width="720"><br>

### Commands

Browse server help in one tab and LuaHZ commands in another.

<img src="docs/images/gallery-v042/server-commands.png" alt="Commands" width="720"><br>
<img src="docs/images/gallery-v042/mod-commands.png" alt="LuaHZ command reference" width="720"><br>

### Server

The Server tab's pages follow their in-game order.

#### Families

Search the complete family list, including entries that scroll out of game chat.

<img src="docs/images/gallery-v042/server-families.png" alt="Server: Families" width="720"><br>

#### Members

Browse online family members with their rank numbers and names.

<img src="docs/images/gallery-v042/server-members.png" alt="Server: Members" width="720"><br>

#### Rules

<img src="docs/images/gallery-v042/server-rules.png" alt="Server rules" width="720"><br>

#### Settings

<img src="docs/images/gallery-v042/server-settings.png" alt="Server settings snapshot" width="720"><br>

Server settings are a snapshot, separate from LuaHZ preferences. Version observations are informational and do not automatically disable features.

#### Links

<img src="docs/images/gallery-v042/server-links.png" alt="Server links" width="720"><br>

#### Status

<img src="docs/images/gallery-v042/server-status.png" alt="Server status" width="720"><br>

### Settings

Choose **Graphite + Ice Blue** (the default), **Midnight + Periwinkle**, or **Carbon + Sea Glass** under **Appearance → Theme**. Your choice is saved with your preferences. Appearance Reset returns to Graphite without changing interface scaling or HUD layout; those controls remain in their own sections.

<img src="docs/images/gallery-v042/interface-settings.png" alt="Interface settings" width="720"><br>

**Midnight + Periwinkle**

<img src="docs/images/gallery-v042/theme-midnight.png" alt="Midnight + Periwinkle theme" width="720"><br>

**Carbon + Sea Glass**

<img src="docs/images/gallery-v042/theme-carbon.png" alt="Carbon + Sea Glass theme" width="720"><br>

### Changelog

Review the version history from LuaHZ settings.

<img src="docs/images/gallery-v042/changelog.png" alt="LuaHZ changelog" width="720"><br>

### Character Status

Press I for Character, Work, Finances, Health, Inventory and Licenses tabs. The screenshots below follow the tab order.

<img src="docs/images/gallery-v042/character.png" alt="Character Status" width="720"><br>

**Work**

<img src="docs/images/gallery-v042/character-work.png" alt="Character work" width="720"><br>

**Finances**

<img src="docs/images/gallery-v042/character-finances.png" alt="Character finances" width="720"><br>

**Health**

<img src="docs/images/gallery-v042/character-health.png" alt="Character health" width="720"><br>

**Inventory**

<img src="docs/images/gallery-v042/character-inventory.png" alt="Character inventory" width="720"><br>

**Licenses** — view the server-received Driver's, Pilot and Boating license statuses; Refresh requests a new snapshot.

<img src="docs/images/gallery-v042/character-licenses.png" alt="Character licenses" width="720"><br>

### Quick Actions

Press U for navigation, skills, job locations and help, plus actions matched to your current jobs. Compact tiles are grouped under **General** and the detected job names, with separate sections when both jobs provide actions. Detective tools appear for detectives. Some actions open a form for a player, price or choice; the server checks requirements.

<img src="docs/images/gallery-v042/quick-actions.png" alt="Quick Actions" width="720"><br>

### Find player

Select an online name or ID. The server checks detective-job access.

### Vehicle menu

Press **K** for the panel aligned above the vehicle dashboard. Trunk opens on foot; Controls opens inside a vehicle. Keep moving or driving while it stays visible. Use the rounded key hints on the active tab, or hold **Alt** to click. **[ / ]** change tabs; **K** or **Escape** closes the panel. Configured settings/menu bindings take priority over conflicting contextual hints.

**Controls** use ordinary server commands for engine, lights, window, hood, trunk and locks. Engine, lights, window and hood require the driver; trunk and locks also work nearby on foot. Availability still depends on the server and vehicle.

| Vehicle tab | Contextual shortcuts |
|---|---|
| Controls | **E** engine, **L** lights, **O** window, **U** doors, **H** hood, **B** trunk |
| Trunk | **B** trunk, **C** contents/balance |
| My vehicles | **V** storage, **R** start/stop tracking |

Shortcuts apply only while that tab is open. Chat, native dialogs and other input-blocking interfaces suspend vehicle actions. Existing command eligibility, confirmations and repeat protection still apply. Quick replies keep the current status/hint; a longer wait is shown once in the footer after about a second. Trunk contents have their own loading message.

<img src="docs/images/gallery-v042/vehicle-controls.png" alt="Vehicle controls" width="472"><br>

On foot, disabled controls explain **Driver only**. Doors and Trunk describe nearby actions instead of claiming a known state for an unidentified vehicle.

<img src="docs/images/gallery-v042/vehicle-controls-onfoot.png" alt="On-foot vehicle actions" width="472"><br>

**Trunk** opens/closes the nearby trunk and shows **Trunk balance** on foot. Menu balance requests stay silent; typing `/trunkbalance` yourself keeps normal chat output.

<img src="docs/images/gallery-v042/vehicle-trunk.png" alt="Trunk controls" width="472"><br>

<img src="docs/images/gallery-v042/vehicle-trunk-balance.png" alt="Trunk balance viewer with contents" width="472"><br>

**My vehicles** opens storage or starts/stops tracking. Choose the vehicle in the server menu; check Spawned/Stored status before confirming. Stored vehicles need spawning before tracking.

<img src="docs/images/gallery-v042/vehicle-my-vehicles.png" alt="Vehicle storage and tracking" width="472"><br>

<img src="docs/images/gallery-v042/vehicle-tracking-active.png" alt="Active vehicle tracking and last location" width="472"><br>

Vehicle tracking starts/stops through the existing bottom-right toast channel; its old persistent label above the radar is removed.

The server supplies the vehicle selection dialog.

<img src="docs/images/gallery-v042/vehicle-tracking-dialog.png" alt="Server vehicle tracking selection dialog" width="426"><br>

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

**0.4.2 — Loading Forward** combines the open.mp 1.7.0 loading fix with three selectable themes, compact Quick Actions and job headings, Science Gothic HUD/dashboard labels, legacy Pricedown cash/clock lettering, a sharper Proper Radar Quickmap and the Changelog tab crash fix. The loading helper passed owner checks on Windows 11 with open.mp 1.7.0/build 7, open.mp 1.6.1/build 6 and classic SA-MP R5. The newer themes, compact Trucker layout, fonts and map appearance were accepted in the open.mp test copy; the owner subsequently passed the combined source snapshot on classic SA-MP R5 and open.mp 1.7.0, including the stable font resource paths. Exact release archive acceptance is recorded separately before publication. No gameplay features or server commands changed. See [changes](docs/releases/0.4.2.md) and [open.mp QA](docs/OPENMP_QA.md), including the independently reproduced foreign-server black-splash limitation. Linux/Wine owner gameplay QA covers 0.4.0.

## Documentation

| Guide | Purpose |
|---|---|
| [Installation](docs/INSTALLATION.md) | Prerequisite layout and troubleshooting |
| [Recovery](docs/RECOVERY.md) | Restore a previous installation |

## License and acknowledgments

Original LuaHZ code is [MIT licensed](LICENSE). The mimgui adapter and Lucide icons retain their upstream notices. External software and artwork retain their own terms. See [third-party notices](THIRD_PARTY.md).

### Visual credits

| Asset | Creator and source |
|---|---|
| Map artwork | [Proper Radar by Junior_Djjr](https://www.mixmods.com.br/2022/07/proper-radar/), based on Grove Street Games (GTA Trilogy) and Jéssica Natália; Quickmap adaptation by LuaHZ contributors |
| Weapon icons | [Zera's HQ Weapon Icons](https://www.gtagarage.com/mods/show.php?id=21062) |
| Menu font | [Rubik Project Authors](https://github.com/googlefonts/rubik), SIL OFL 1.1 |
| HUD/dashboard labels | [Science Gothic](https://github.com/googlefonts/science-gothic), Font Detective LLC; Thomas Phinney, Vassil Kateliev and Brandon Buerkle, SIL OFL 1.1 |
| Cash/clock lettering | Pricedown by Ray Larabie, legacy 3.200 (2004) copy from [GTA-SanAndreas.com](https://www.gta-sanandreas.com/downloads/); original agreement included |
| Identified HD radar icons | [-Quantum-'s Original Radar Icons in HQ](https://www.gtagarage.com/mods/show.php?id=26910); 61 current sprites match this original pack |
| Native font and wanted-star inputs | Owner-supplied DJDARKO 2025 v1.0.1 pack; existing appearance retained |
| Standard skin previews | Images linked by the [open.mp skin gallery](https://open.mp/docs/scripting/resources/skins) |

These credits identify the sources currently recorded. Individual notices, licenses and remaining provenance details are in [third-party notices](THIRD_PARTY.md); LuaHZ's MIT license applies to its original code.

LuaHZ was inspired by the visible feature set of [LunaHZ](https://forums.hzgaming.net/showthread.php/562577-LunaHZ-HUD-Quickmap-amp-more) ([project page](https://github.com/lunahz/)). LuaHZ is a separate project and is not affiliated with LunaHZ, Horizon Gaming, Rockstar Games, SA-MP, or its prerequisite authors.

## Support

If you find this project or any of my open-source work helpful, consider supporting future development:

- 💖 [Sponsor on GitHub](https://github.com/sponsors/amir0ff)
- ☕ [Buy me a coffee on Ko-fi](https://ko-fi.com/amir0ff)
