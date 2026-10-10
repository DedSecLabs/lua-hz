# Installation guide

**Player download:** [LuaHZ 0.2.35](https://github.com/DedSecLabs/lua-hz/releases/tag/v0.2.35-player). Windows copies `moonloader` and `LuaHZLoading.asi` into the GTA folder. Linux/Wine can use `install.sh` from that archive. [BASE_INSTALL.md](BASE_INSTALL.md) describes the earlier small preview, which omits the visuals.

LuaHZ 0.2.35 targets classic **GTA San Andreas 1.0 US**, **SA-MP 0.3.7 R5** and the prerequisite versions linked in the [README](../README.md#installation). This guide documents that prerequisite setup. The repository source ZIP is not the player download.

## What you can install today

Install the prerequisites below, then download `LuaHZ-0.2.35-player.zip` from [Releases](https://github.com/DedSecLabs/lua-hz/releases/tag/v0.2.35-player). GitHub’s **Code → Download ZIP** contains developer source and cannot replace that package. Python, GCC and LuaJIT build tools are for contributors, not prerequisites players need to install separately.

## Find your game folder

The **GTA folder** means the folder containing `gta_sa.exe` and `samp.exe`. On Windows, right-click your game shortcut, select **Properties**, and use **Open File Location** to find it. All references to `moonloader/lib` below mean that folder inside this same GTA installation.

When extracting a ZIP, open it first and look for the runtime files described below. Copy those files into the stated destination, rather than placing the ZIP or an extra wrapper folder there. Keep the remaining library files supplied by each author.

## Before installing

1. Confirm that your existing GTA/SA-MP installation can connect to Horizon normally.
2. Close GTA and the SA-MP browser.
3. Back up the installation and existing MoonLoader settings. Keep existing shared loaders/libraries if they already match the tested versions; avoid mixing different ASI loader implementations.
4. Use **x86** mod components even on a 64-bit operating system.

## Prerequisite installation order

Use the exact links in the [README prerequisite table](../README.md#2-install-the-tested-prerequisites).

1. **SA-MP 0.3.7 R5:** Use Horizon's download page and select the `sa-mp-0.3.7-R5-2-MP-install.exe` installer. Select the folder containing `gta_sa.exe` when installing. A different installer carrying the R5 label has not been validated as equivalent; compare the installed `samp.dll` fingerprint in the manifest.
2. **CLEO 4.4.4 and its ASI loader:** Extract the official `CLEO4.zip`. Install its runtime files into the GTA folder using the included README. Our tested loader is **Silent's ASI Loader 1.2**, supplied in this ZIP as `vorbisFile.dll` and `vorbisHooked.dll`. The separate download on [Silent's site](https://silentsblog.com/mods/gta-sa/#asiloader) is a different version; it is not the pinned baseline. Developer SDK and demonstration files are not required to play.
3. **MoonLoader 0.26.5-beta:** Extract the author’s archive into the same GTA folder. Keep `MoonLoader.asi`, its supplied runtime DLLs and the complete `moonloader/lib` directory. Do not install only the ASI. The archive's `vkeys`, `windows.message`, encoding and other helper modules are part of this setup.
4. **SAMPFUNCS 5.7.1 rel.25 for R5:** Open the author’s thread or the specific R5 attachment and follow its included installation instructions. Place `SAMPFUNCS.asi` in the GTA folder. An R1/R3 build is not interchangeable with the tested R5 build. A browser challenge or login may be required.
5. **mimgui 1.7.0:** Download `mimgui-v1.7.0.zip` from the pinned release's **Assets** section, not GitHub's source archive. Merge its library payload into `moonloader/lib`, so `moonloader/lib/mimgui/init.lua` and `moonloader/lib/mimgui/cimguidx9.dll` exist. Avoid an extra nested `mimgui/mimgui` directory.
6. **SAMP.Lua:** Use the pinned 2.0.4 source archive, copy the entire `samp` directory to `moonloader/lib/samp`, and apply the baseline adjustment below. Do not replace it with the current master branch or latest release when reproducing our tests.

Original GTA and SAMPFUNCS files must remain unmodified on disk for LuaHZ's native visual installation. Older globally patched loading screens/fonts/maps need the guarded migration described in [development](DEVELOPMENT.md), rather than overwriting them by hand.

## SAMP.Lua baseline

This is an advanced step for reproducing the exact tested library. It edits a Lua text file; the pinned upstream ZIP alone does not contain our adjustment. If you are unfamiliar with editing code, stop here until the player package provides a tested setup path. Do not guess at changes to this file.

Our installed SAMP.Lua is **v2.0.4 with a two-line material-handler adjustment**. All eight installed Lua files were compared against the [pinned v2.0.4 source](https://github.com/THE-FYP/SAMP.Lua/tree/v2.0.4/samp): the other seven match exactly; `events/handlers.lua` has the two additional assignments below. We have not identified this complete copy as a separate upstream release, so it is not labeled as one.

Download the [v2.0.4 source ZIP](https://github.com/THE-FYP/SAMP.Lua/archive/refs/tags/v2.0.4.zip). After copying its `samp` folder, open `moonloader/lib/samp/events/handlers.lua`. In `handler.on_create_object_reader`, find the material action branches near the end of the function. Add `data.actionType = actionType` after each insertion, so those branches read:

```lua
if actionType == 1 then
    table.insert(data.materials, read_object_material(bs))
    data.actionType = actionType
elseif actionType == 2 then
    table.insert(data.materials_text, read_object_material_text(bs))
    data.actionType = actionType
end
```

Preserve the surrounding code and FYP's existing copyright/license notice. This excerpt describes the baseline adjustment to FYP's MIT-licensed library; it is not a requirement to modify game or server data. Save using the file's existing LF line endings to reproduce the recorded file hash. Installed hashes for all eight files are in [the manifest](../manifests/dependencies.json).

## Expected prerequisite layout

```text
GTA San Andreas/
├── gta_sa.exe
├── samp.exe
├── samp.dll
├── CLEO.asi
├── cleo/
├── vorbisFile.dll
├── vorbisHooked.dll
├── MoonLoader.asi
├── SAMPFUNCS.asi
├── bass.dll
├── lua51.dll
└── moonloader/
    └── lib/
        ├── moonloader.lua
        ├── sampfuncs.lua
        ├── vkeys.lua
        ├── windows/message.lua
        ├── mimgui/
        │   ├── init.lua
        │   └── cimguidx9.dll
        └── samp/
            ├── events.lua
            └── events/
```

This is a layout checklist, not a full archive inventory. The prerequisite archives include additional required library files. Do not trim a working library to the handful of filenames shown here.

## Installing LuaHZ itself

**Player package:** [LuaHZ-0.2.35-player.zip](https://github.com/DedSecLabs/lua-hz/releases/download/v0.2.35-player/LuaHZ-0.2.35-player.zip). On Windows, merge `payload/moonloader` into the GTA folder and copy `payload/LuaHZLoading.asi` next to `gta_sa.exe`. On Linux/Wine, run `install.sh` from the extracted archive. Downloads labeled **developer preview** and GitHub’s automatic **Source code** archives are for contributors.

**Source/local testing:** Use [the development guide](DEVELOPMENT.md) to check/build the source and deploy it with backups. Our Lua entry point is historically named `HorizonBase.lua`; it belongs in `moonloader`, and `src/lib/horizonbase` becomes `moonloader/lib/horizonbase`. Use the deployment tools to stage the licensed UI icons and available external resources; copying only that Lua file is insufficient.

The player ZIP already contains `LuaHZVisuals.dll`, the native visual files, and the matched `LuaHZLoading.asi` / `loading.enc` pair. See [assets](ASSETS.md) and [recovery](RECOVERY.md).

## Verify the installation

With LuaHZ deployed, launch Horizon from the same SA-MP browser you normally use:

- A LuaHZ notification appears at the bottom right.
- **F9** or `/luahz` opens settings; **M** opens Quickmap; **I** opens Character Status.
- While driving a road vehicle, **X** toggles cruise control; **Numpad + / −** (or **= / −** on the main keyboard) adjusts the target by 1 mph. Brake or press **X** again to cancel. See the [README controls table](../README.md#4-check-an-installed-copy) for cruise preset shortcuts.
- Exit the game, connect to another server, and verify LuaHZ UI/custom visuals remain inactive.
- Exit again and reconnect to Horizon; LuaHZ should activate normally.

The shared-installation workflow above has passed the owner's in-game QA on Wine. It does not establish compatibility with every client build, mod combination or native Windows installation.

## Troubleshooting

| What you see | What to check |
|---|---|
| No LuaHZ notification or settings on Horizon | Confirm LuaHZ itself is installed, not just its prerequisites. Check that `HorizonBase.lua` is directly inside `moonloader` and `lib/horizonbase` is complete. Read `moonloader/moonloader.log` for the first error. |
| An error mentions `mimgui` or `samp.events` | Compare your folders with the layout above; an extra ZIP wrapper folder is a common cause. Use the pinned versions. |
| Menus work but maps, portraits or custom fonts are missing | The source ZIP excludes several visual resource packs. See [assets](ASSETS.md); reinstalling prerequisites will not supply those resources. |
| LuaHZ does not activate on another server | This is expected. It activates only on Horizon’s supported endpoint. |
| The game stops starting after adding prerequisites | Close the game and browser, then restore your backup. Record the exact error before changing more files. |

If you need help, open an issue at [DedSecLabs/lua-hz](https://github.com/DedSecLabs/lua-hz/issues) with your OS/Wine version, prerequisite versions, the action that failed, and the relevant error lines. Remove passwords, account details and personal paths from shared logs.

## Missing runtime components

On Windows, missing `d3dx9_25.dll` or `d3dx9_43.dll` points to legacy DirectX helper requirements. Use Microsoft's [DirectX End-User Runtimes, June 2010](https://www.microsoft.com/en-us/download/details.aspx?id=8109). Extract the package and run its `DXSETUP.exe`; installing the current Windows DirectX version alone does not provide every legacy helper.

For missing `VCRUNTIME140.dll` / UCRT components, use Microsoft's [supported Visual C++ guidance](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist) and its [x86 installer](https://aka.ms/vc14/vc_redist.x86.exe). This Microsoft runtime is a compatible system dependency, not a frozen LuaHZ prerequisite version. Do not seek individual DLLs from random download sites.

On Linux/Wine, install prerequisites inside the **same Wine prefix** as the game. The tested environment is Wine 11.0 via GE-Proton11-7; a universal Lutris/Wine recipe is not yet validated. Consult [Windows/Wine QA](WINDOWS_WINE_PREREQUISITE_QA.md) before changing DLL overrides or runners.

## Download and fingerprint verification

[manifests/dependencies.json](../manifests/dependencies.json) records the exact installed-file SHA-256 hashes and verified archive hashes. On Windows, compare with PowerShell:

```powershell
Get-FileHash '.\MoonLoader.asi' -Algorithm SHA256
```

On Linux:

```sh
sha256sum MoonLoader.asi
```

Use archive hashes for downloaded ZIPs and installed-file hashes for extracted files; they are different checks. mimgui's installed Lua files use LF while the official 1.7.0 ZIP uses CRLF: source text and the renderer DLL match, but raw Lua hashes differ until line endings are normalized.

The CLEO 4.4.4 and MoonLoader archives were fetched and matched during the earlier dependency audit. The mimgui 1.7.0 renderer and normalized Lua sources were matched during this README review. The SAMPFUNCS page identifies the R5 attachment, but its download challenge prevented upstream byte comparison; our recorded hash is the locally tested binary. Horizon's installer download also returned HTTP 403 during automated retrieval. These links require manual download verification before claiming a completely reproducible fresh player installation.
