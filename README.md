<div align="center">

# LuaHZ

<p align="center">
  <img src="assets/branding/luahz-logo.png" alt="LuaHZ logo" width="200">
</p>

**A modern HUD and quality-of-life toolkit for Horizon Roleplay.**

**0.2.35** · MoonLoader · GTA San Andreas · SA-MP 0.3.7 R5

[Horizon Gaming](https://hzgaming.net/) · [Downloads](https://github.com/DedSecLabs/lua-hz/releases) · [Installation](#installation) · [Features](#features) · [Development](#development) · [Documentation](#documentation)

</div>

---

LuaHZ brings clearer player and vehicle information, a useful map and configurable controls to **Horizon Gaming / Horizon Roleplay**. It activates only on `samp.hzgaming.net:7777` / `213.32.6.232:7777`. You can continue using the same SA-MP installation for other servers.

> **Download:** [LuaHZ 0.2.35](https://github.com/DedSecLabs/lua-hz/releases/tag/v0.2.35-player) is the playable release for Linux and Windows. It includes the HUD, Quickmap, portraits, native visuals, and loading artwork. Prerequisites remain separate. On Windows, copy the files into the GTA folder. On Linux, use the included installer. GitHub's automatic source ZIP is developer source.

## Features

| Area | What LuaHZ adds |
|---|---|
| HUD | Player information, stamina and oxygen indicators, vehicle speed and health |
| Quickmap | Saved Horizon locations and configurable map display |
| Character Status | Skin portrait, live player information and tabbed server statistics |
| Controls | Editable shortcuts, custom command bindings and cruise control |
| Performance | Configurable FPS limits for different game contexts |
| Horizon helpers | Ordinary server commands, offer handling and tracking tools |
| Visuals | HZ-specific loading artwork, fonts, radar icons and map textures with the separate visual package |

Live health, armor, cash and skin information come from the game client. Account, job and inventory information use recognized server responses. See [data sources](docs/DATA_SOURCES.md).

## Installation

**New to mods?** Start with the [step-by-step prerequisite guide](docs/INSTALLATION.md). The playable download is [LuaHZ 0.2.35](https://github.com/DedSecLabs/lua-hz/releases/tag/v0.2.35-player).

### 1. Prepare your game

Start with a working **classic GTA San Andreas 1.0 US** installation and **SA-MP 0.3.7 R5**. Connect to Horizon once before adding mods. GTA Definitive Edition and other client builds are outside the tested setup.

Close **both GTA and the SA-MP browser** before installing or updating files. Keep a backup of your working installation.

### 2. Install the tested prerequisites

Install these **in the order shown**, with GTA and SA-MP closed. Use the named **32-bit (x86)** versions even on 64-bit Windows.

Your **GTA folder** is the folder containing `gta_sa.exe`. Paths such as `moonloader/lib` are inside that folder. Open each ZIP and copy its runtime files to the destination below; do not copy the ZIP itself or an extra wrapper folder. Keep the complete supplied libraries.

| Download — tested version | Where it goes / what to do |
|---|---|
| **1. SA-MP 0.3.7 R5** — [Horizon download page](https://hzgaming.net/fullpage.php?id=download); choose `R5-2-MP` | Run the installer and select your **GTA folder**. Afterwards, `samp.exe` and `samp.dll` should be beside `gta_sa.exe`. |
| **2. CLEO 4.4.4 + ASI loader** — [CLEO4.zip](https://github.com/cleolibrary/CLEO4/releases/download/v4.4.4/CLEO4.zip) | Follow the ZIP's README to install its runtime files in your **GTA folder**. Use its supplied **Silent's ASI Loader 1.2** (`vorbisFile.dll` and `vorbisHooked.dll`). Developer SDK/examples are not required. |
| **3. MoonLoader 0.26.5-beta** — [author's thread](https://www.blast.hk/threads/13305/) · [archive](https://blast.hk/moonloader/download.php?archive) | Extract its runtime payload into your **GTA folder**. Keep `MoonLoader.asi`, the supplied runtime DLLs and the complete `moonloader/lib` folder. |
| **4. SAMPFUNCS 5.7.1 rel.25, R5 build** — [author's thread](https://www.blast.hk/threads/17/) · [R5 attachment](https://www.blast.hk/attachments/255877/) | Follow the included instructions. `SAMPFUNCS.asi` belongs in your **GTA folder**. Choose the **R5** build; R1/R3 builds are not interchangeable. |
| **5. mimgui 1.7.0** — [release Assets](https://github.com/THE-FYP/mimgui/releases/tag/v1.7.0); choose `mimgui-v1.7.0.zip` | Merge its library payload into **`moonloader/lib`**. Check that `moonloader/lib/mimgui/init.lua` and `mimgui/cimguidx9.dll` exist there. |
| **6. SAMP.Lua 2.0.4 + baseline adjustment** — [v2.0.4 source ZIP](https://github.com/THE-FYP/SAMP.Lua/archive/refs/tags/v2.0.4.zip) | Copy the complete **`samp` folder into `moonloader/lib`**, producing `moonloader/lib/samp/events.lua`. The tested setup also needs the [two-line adjustment](docs/INSTALLATION.md#samplua-baseline); the ZIP alone does not include it. |

On **Linux/Wine**, install all prerequisites inside the **same Wine prefix as this game copy**. See the [Windows/Wine guide](docs/WINDOWS_WINE_PREREQUISITE_QA.md) for the tested environment.

Some downloads require browser verification. The MoonLoader archive link can change: confirm **0.26.5-beta** and its recorded hash. The [installation guide](docs/INSTALLATION.md) provides the complete folder checklist, download verification and troubleshooting; the [dependency manifest](manifests/dependencies.json) records the tested file hashes.

If Windows reports missing DirectX helper DLLs or Visual C++ runtimes, use Microsoft's [DirectX June 2010 package](https://www.microsoft.com/en-us/download/details.aspx?id=8109) and [Visual C++ x86 runtime guidance](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist). These are conditional system requirements; compatible components already installed need no duplicate installation.

### 3. Install LuaHZ

**Players:** Download **LuaHZ-0.2.35-player.zip** from the [player release](https://github.com/DedSecLabs/lua-hz/releases/tag/v0.2.35-player) and follow INSTALL.md inside the archive. Windows is a copy of `moonloader` and `LuaHZLoading.asi` into the GTA folder. Linux/Wine can use `install.sh`. The verified SAMP.Lua adjustment is included, so skip the separate SAMP.Lua download. The developer preview and automatic source ZIPs remain contributor downloads.

**For contributors or local testers:** Follow the [source build and controlled deployment guide](docs/DEVELOPMENT.md). Deployment tools preserve backups and preferences. Full visual deployment requires the external resources listed in the [asset inventory](docs/ASSETS.md).

### 4. Check an installed copy

Once you have an installed LuaHZ copy, add `samp.hzgaming.net:7777` to the SA-MP browser and connect. Then a notification appears at the **bottom right**. Default controls are:

| Control | Action |
|---|---|
| **F9** or `/luahz` | Open settings |
| **M** | Open Quickmap |
| **I** | Open Character Status |
| **X** | Toggle cruise control at your current speed |
| **Numpad + / −** or **= / −** | Raise/lower the cruise target by 1 mph while cruise is active |
| **Numpad 1 / 2 / 3** | Activate cruise at the configured presets: **50 / 80 / 120 mph** by default |

Open **Settings → Hotkeys** to change configurable shortcuts and cruise preset speeds. Cruise control works while you are driving a road vehicle; brake or press **X** again to cancel.

On other servers, LuaHZ features and custom visuals remain inactive. The minimal endpoint/startup selectors remain installed, and original game/plugin files stay stock on disk. The HZ → other server → HZ workflow has passed user testing with one installation.

## Compatibility

The tested native target is **GTA SA 1.0 US / SA-MP R5 / SAMPFUNCS 5.7.1 rel.25**. Unknown builds keep the original native behavior. Linux/Wine gameplay is recorded. Windows uses the same files, copied into the GTA folder. See [current status](docs/STATUS.md) and [QA coverage](docs/QA.md).

## Development

Source checks require **Python 3.11+**, **LuaJIT 2.1** and **GCC**. They run without GTA, an account or private artwork:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python tools/check.py --luajit /path/to/luajit
```

Native build tools, deployment, recovery and fresh-clone verification are covered in [development](docs/DEVELOPMENT.md). Read [contributor instructions](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) before making changes.

## Documentation

| Guide | Purpose |
|---|---|
| [Installation](docs/INSTALLATION.md) | Prerequisite layout, exact versions and troubleshooting |
| [Status](docs/STATUS.md) | Accepted baseline and remaining release work |
| [Architecture](docs/ARCHITECTURE.md) | Runtime structure, server isolation and ownership |
| [Development](docs/DEVELOPMENT.md) | Build, check and deploy the project |
| [Assets](docs/ASSETS.md) | Included assets and separately acquired resources |
| [Recovery](docs/RECOVERY.md) | Restore a previous working installation |
| [QA](docs/QA.md) | Offline verification and in-game test coverage |
| [Releases](docs/RELEASING.md) | Draft automation, download types and player-release preparation |

## License and acknowledgments

Original LuaHZ code is [MIT licensed](LICENSE). The mimgui adapter and Lucide icons retain their upstream notices; external software and artwork retain their own terms. See [third-party notices](THIRD_PARTY.md).

LuaHZ is an independent project informed by the visible LunaHZ feature baseline. No affiliation with Horizon Gaming, Rockstar Games, SA-MP or the prerequisite authors is implied.
