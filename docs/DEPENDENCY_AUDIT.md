# Dependency audit

Current fingerprints and versions are in manifests/dependencies.json. The approved installation uses MoonLoader 0.26.5-beta, SAMPFUNCS 5.7.1 rel.25 R5, CLEO 4.4.4, the compatible ASI loader and mimgui/SAMP.Lua libraries. The native helpers support only the verified GTA SA 1.0 US / SA-MP R5 image metadata/layouts; fingerprints describe locally tested binaries, not a broader guarantee about every similarly named distribution.

The October 9 README review identifies the loader as Silent's ASI Loader 1.2 from the CLEO 4.4.4 ZIP. mimgui matches release 1.7.0: the renderer matches byte-for-byte and its four Lua files match after CRLF/LF normalization. SAMP.Lua matches v2.0.4 in seven of eight files; the material handler contains two additional `data.actionType = actionType` assignments. The documented adjustment was applied to upstream v2.0.4 in memory and reproduced the installed SHA-256 exactly. See [installation](INSTALLATION.md) for the exact reproduction steps and upstream links. Neither library was changed in the game during this audit.

CLEO and MoonLoader archive hashes were matched against upstream during the earlier audit. SAMPFUNCS attachment retrieval remains browser-challenge restricted, and automated HZ installer retrieval returned HTTP 403; their local tested fingerprints are not a claim of a new upstream byte comparison. The README distinguishes pinned release downloads from mutable URLs and conditional Microsoft system runtimes.

Runtime libraries remain external. MoonLoader/mimgui/SAMPFUNCS can require compatible x86 DirectX helper DLLs and C runtimes in Windows/Wine; see WINDOWS_WINE_PREREQUISITE_QA.md. Our native components import only KERNEL32 and add no CRT dependency. The Lua project uses mimgui, not DXUT, and ordinary SAMP.Lua/MoonLoader APIs.

Source setup/check/build instructions are in DEVELOPMENT.md. Source checks are independent of game assets and a live server. Developer compilers and Pillow are tooling dependencies, not end-user runtime requirements. The CI workflow is prepared; hosted GitHub execution is not yet claimed.

Public publication is source-only with retained MIT/ISC notices. Game/plugin installers/binaries and unverified visual assets are not bundled. ASSETS.md describes unresolved rights and external acquisition roles. Detailed historical package-download/import investigations and machine paths remain in ignored local archives; current source does not depend on those logs.
