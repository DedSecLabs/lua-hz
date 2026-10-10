<div align="center">

# LuaHZ

<p align="center">
  <a href="https://github.com/DedSecLabs/lua-hz/releases/tag/v0.2.35-player"><img src="https://img.shields.io/badge/release-0.2.35-2563eb" alt="release 0.2.35"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-64748b" alt="license MIT"></a>
</p>

<p align="center">
  <img src="assets/branding/luahz-logo.png" alt="LuaHZ logo" width="200">
</p>

<img width="1024" height="576" alt="image" src="https://github.com/user-attachments/assets/91f22112-672e-4db0-abca-1ad27f263950" />


**A modern HUD and quality-of-life toolkit for Horizon Roleplay.**

It activates only on `samp.hzgaming.net:7777` / `213.32.6.232:7777`. The same SA-MP installation can still join other servers.

[Download](https://github.com/DedSecLabs/lua-hz/releases/tag/v0.2.35-player) · [Install](#install) · [Controls](#controls) · [Features](#features) · [Development](#development)

</div>

---

## Install

Download **[LuaHZ-0.2.35-player.zip](https://github.com/DedSecLabs/lua-hz/releases/download/v0.2.35-player/LuaHZ-0.2.35-player.zip)**. GitHub's automatic source ZIP is developer source, not this download.

### 1. Prepare the game

Start with classic **GTA San Andreas 1.0 US** and **SA-MP 0.3.7 R5**. Connect to Horizon once before adding mods. GTA Definitive Edition and other client builds are outside the tested setup.

Close **GTA and the SA-MP browser** before copying files. Your **GTA folder** is the folder that contains `gta_sa.exe`.

### 2. Install the prerequisites

Install these **in order**, with GTA and SA-MP closed. Use the named **32-bit (x86)** versions even on 64-bit Windows. Open each ZIP and copy its runtime files to the destination below. Keep the complete supplied libraries.

The player ZIP already contains the adjusted SAMP.Lua files, so skip row 6 when you use that download.

| Download — tested version | Where it goes |
|---|---|
| **1. SA-MP 0.3.7 R5** — [Horizon download page](https://hzgaming.net/fullpage.php?id=download); choose `R5-2-MP` | Run the installer and select your **GTA folder**. `samp.exe` and `samp.dll` should sit beside `gta_sa.exe`. |
| **2. CLEO 4.4.4 + ASI loader** — [CLEO4.zip](https://github.com/cleolibrary/CLEO4/releases/download/v4.4.4/CLEO4.zip) | Follow the ZIP's README. Use its supplied **Silent's ASI Loader 1.2** (`vorbisFile.dll` and `vorbisHooked.dll`) in your **GTA folder**. The developer SDK is not required. |
| **3. MoonLoader 0.26.5-beta** — [author's thread](https://www.blast.hk/threads/13305/) · [archive](https://blast.hk/moonloader/download.php?archive) | Extract the runtime into your **GTA folder**. Keep `MoonLoader.asi`, the supplied DLLs, and the complete `moonloader/lib` folder. Confirm the version **0.26.5-beta**; the archive link can change. |
| **4. SAMPFUNCS 5.7.1 rel.25, R5 build** — [author's thread](https://www.blast.hk/threads/17/) · [R5 attachment](https://www.blast.hk/attachments/255877/) | Put `SAMPFUNCS.asi` in your **GTA folder**. Use the **R5** build. R1 and R3 builds are not interchangeable. |
| **5. mimgui 1.7.0** — [`mimgui-v1.7.0.zip`](https://github.com/THE-FYP/mimgui/releases/tag/v1.7.0) | Merge its library into **`moonloader/lib`**. `moonloader/lib/mimgui/init.lua` and `mimgui/cimguidx9.dll` should exist. |
| **6. SAMP.Lua** — included in the player ZIP | Skip this row for the player download. A source setup copies [v2.0.4](https://github.com/THE-FYP/SAMP.Lua/archive/refs/tags/v2.0.4.zip) into `moonloader/lib` and applies the [two-line adjustment](docs/INSTALLATION.md#samplua-baseline). |

On **Linux/Wine**, install the prerequisites inside the **same Wine prefix** as this game copy. If Windows reports missing DirectX or Visual C++ files, use Microsoft's [DirectX June 2010 package](https://www.microsoft.com/en-us/download/details.aspx?id=8109) and [Visual C++ x86 runtime](https://aka.ms/vc14/vc_redist.x86.exe). The [installation guide](docs/INSTALLATION.md) has the folder checklist and troubleshooting.

### 3. Add LuaHZ

Close GTA and the SA-MP browser. Extract the player ZIP outside the GTA folder.

**Windows:** merge `payload/moonloader` into the GTA `moonloader` folder. Copy `payload/LuaHZLoading.asi` next to `gta_sa.exe`.

**Linux/Wine:** from the extracted folder, run:

```sh
bash install.sh "/path/to/GTA San Andreas"
```

The path must contain `gta_sa.exe`. The script checks the tested program versions, backs up replaced files, and can roll the copy back.

### 4. Join Horizon

Add `samp.hzgaming.net:7777` in the SA-MP browser and connect. A LuaHZ notice appears at the **bottom right**.

## Controls

| Control | Action |
|---|---|
| **F9** or `/luahz` | Open settings |
| **M** | Open Quickmap |
| **I** | Open Character Status |
| **X** | Toggle cruise control at your current speed |
| **Numpad + / −** or **= / −** | Raise or lower the cruise target by 1 mph |
| **Numpad 1 / 2 / 3** | Cruise at **50 / 80 / 120 mph** |

Change shortcuts and preset speeds in **Settings → Hotkeys**. Cruise works while you drive a road vehicle. Brake, or press **X** again, to cancel.

## Features

| Area | What LuaHZ adds |
|---|---|
| HUD | Player information, stamina and oxygen, vehicle speed and health |
| Quickmap | Saved Horizon locations and a configurable map |
| Character Status | Skin portrait, live player information, and tabbed server statistics |
| Controls | Editable shortcuts, custom command bindings, and cruise control |
| Performance | FPS limits for different game contexts |
| Horizon helpers | Ordinary server commands, offer handling, and tracking tools |
| Visuals | Loading artwork, fonts, radar icons, and map textures, active only on Horizon |

Live health, armor, cash, and skin come from the game client. Account, job, and inventory information comes from recognized server responses. See [data sources](docs/DATA_SOURCES.md).

## Other servers

On any other server, LuaHZ menus, HUD, and custom visuals stay inactive. Original game and plugin files remain stock on disk. The Horizon → other server → Horizon path has been tested with one installation.

## Development

Source checks need **Python 3.11+**, **LuaJIT 2.1**, and **GCC**. They run without GTA, an account, or the player artwork:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python tools/check.py --luajit /path/to/luajit
```

Build, deploy, and recovery steps are in [development](docs/DEVELOPMENT.md). Read [contributor instructions](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) before making changes.

## Documentation

| Guide | Purpose |
|---|---|
| [Installation](docs/INSTALLATION.md) | Prerequisite layout, versions, and troubleshooting |
| [Status](docs/STATUS.md) | Accepted baseline and remaining work |
| [Architecture](docs/ARCHITECTURE.md) | Runtime structure, server isolation, and ownership |
| [Development](docs/DEVELOPMENT.md) | Build, check, and deploy |
| [Assets](docs/ASSETS.md) | Included assets and separately acquired resources |
| [Recovery](docs/RECOVERY.md) | Restore a previous installation |
| [QA](docs/QA.md) | Offline checks and in-game coverage |
| [Releases](docs/RELEASING.md) | Release workflows and download types |

## License and acknowledgments

Original LuaHZ code is [MIT licensed](LICENSE). The mimgui adapter and Lucide icons retain their upstream notices. External software and artwork retain their own terms. See [third-party notices](THIRD_PARTY.md).

LuaHZ is an independent project informed by the visible LunaHZ feature baseline. No affiliation with Horizon Gaming, Rockstar Games, SA-MP, or the prerequisite authors is implied.
