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

> **Release status:** This repository currently provides **source code**, not a ready-to-install release. Prerequisites are downloaded separately. The full visual package is still being prepared for public distribution; downloading GitHub's source ZIP will not install the complete mod.

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

**New to mods?** Start with the [step-by-step prerequisite guide](docs/INSTALLATION.md). It explains which folder to use, what to copy and how to check your setup. A player install package is still pending; the steps below prepare your game for that release.

### 1. Prepare your game

Start with a working **classic GTA San Andreas 1.0 US** installation and **SA-MP 0.3.7 R5**. Connect to Horizon once before adding mods. GTA Definitive Edition and other client builds are outside the tested setup.

Close **both GTA and the SA-MP browser** before installing or updating files. Keep a backup of your working installation.

### 2. Install the tested prerequisites

Use the versions below to reproduce the tested setup. All game/mod components are **32-bit (x86)**, including on 64-bit Windows. Choose the named version rather than a site's newest release.

| Prerequisite | Tested version | Download / installation |
|---|---|---|
| SA-MP | **0.3.7 R5**; HZ's `R5-2-MP` installer | [Horizon download page](https://hzgaming.net/fullpage.php?id=download) — install into your GTA folder |
| CLEO | **4.4.4** | [Exact release](https://github.com/cleolibrary/CLEO4/releases/tag/v4.4.4) · [CLEO4.zip](https://github.com/cleolibrary/CLEO4/releases/download/v4.4.4/CLEO4.zip) |
| ASI loader | **Silent's ASI Loader 1.2** | Use the loader supplied inside the **CLEO 4.4.4 ZIP above**, matching our installation |
| MoonLoader | **0.26.5-beta** | [Author's thread](https://www.blast.hk/threads/13305/) · [Archive download](https://blast.hk/moonloader/download.php?archive) — retain the included `moonloader/lib` files |
| SAMPFUNCS | **5.7.1 rel.25, R5 build** | [Author's thread](https://www.blast.hk/threads/17/) · [R5 attachment](https://www.blast.hk/attachments/255877/) — choose R5, not R1/R3 |
| mimgui | **1.7.0** | [Exact release](https://github.com/THE-FYP/mimgui/releases/tag/v1.7.0) · [mimgui-v1.7.0.zip](https://github.com/THE-FYP/mimgui/releases/download/v1.7.0/mimgui-v1.7.0.zip) — place `mimgui` in `moonloader/lib` |
| SAMP.Lua | **2.0.4 + two-line material-handler adjustment** | [Pinned release](https://github.com/THE-FYP/SAMP.Lua/releases/tag/v2.0.4) — copy its `samp` folder into `moonloader/lib`, then follow the [exact baseline instructions](docs/INSTALLATION.md#samplua-baseline) |

Some downloads require a browser or challenge verification. Installed-file hashes and download verification details are recorded in the [dependency manifest](manifests/dependencies.json) and [installation guide](docs/INSTALLATION.md). The MoonLoader archive URL is not immutable: confirm its version and hash before installing. An upstream link alone does not establish that every download on that page matches our tested files.

If Windows reports missing DirectX helper DLLs or Visual C++ runtimes, use Microsoft's [DirectX June 2010 package](https://www.microsoft.com/en-us/download/details.aspx?id=8109) and [Visual C++ x86 runtime guidance](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist). These are conditional system requirements; compatible components already installed need no duplicate installation.

### 3. Install LuaHZ

**For players:** Check [GitHub Releases](https://github.com/DedSecLabs/lua-hz/releases) for player downloads. A public LuaHZ install package is not available yet. The prerequisite links above let you prepare your game now. The complete release needs our compiled helpers and separately reviewed visual assets; the source ZIP does not contain them. Files labeled **developer preview** are for contributors and local testers. Choose a file named `LuaHZ-<version>-player.zip` when one becomes available, then follow its included installation guide.

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

The tested native target is **GTA SA 1.0 US / SA-MP R5 / SAMPFUNCS 5.7.1 rel.25**. Unknown builds keep the original native behavior. Gameplay QA has been performed on **Linux/Wine**; native Windows clean-install QA is still pending. See [current status](docs/STATUS.md) and [QA coverage](docs/QA.md).

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
