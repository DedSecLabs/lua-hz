# open.mp compatibility and QA

LuaHZ offers launcher choice with the same supported GTA SA 1.0 US, SA-MP 0.3.7 R5 and verified R5 SAMPFUNCS fingerprints. open.mp launcher versions and SA-MP client versions are separate.

## Accepted local Windows result

The owner passed the exact **0.4.1-rc.1** player checklist on 2026-10-13 in both open.mp and classic SA-MP R5 test copies, including the combined helper, feature/input/preferences checks and the server-switching checklist. Archive SHA-256: `7304d4a5faebea65ec18d4a89162e6e23bc26c80ffda94cca7a8fba59af6a6e0`; packaged source: `b948fd6b207cc500aed17bce544903fdf431aeee`.

The owner then passed the exact final **0.4.1** smoke check in both copies: archive SHA-256 `ab97c3c3200b29143ce72c20f3fd646ac849f5cc9ba4080eb549d78048385727`, source `ba6d972782c24e63d0234e20494b062780e906eb`. All 694 installed payload hashes remained unchanged after acceptance. Linux CI subsequently passed all source/recovery tests (77 Python tests; only the Win32-specific fixture skipped) and both native builds after a formatting-only GCC warning correction. [Validated Linux run](https://github.com/DedSecLabs/luahz/actions/runs/38485104726).

### Foreign-server loading baseline

The owner observed a black loading screen on a **fresh open.mp launch to another server**. It reproduces with LuaHZ's loading helper, Lua entry point and QA probe disabled. It also reproduces in a minimal control with MoonLoader, SAMPFUNCS, CLEO and the winmm proxy disabled. SilentPatch and the ASI loader remained, so this is not a completely unmodified game. The exact cause in open.mp/base-game/profile/remaining components is undetermined; the symptom is reproducible independently of LuaHZ. All seven parked files were restored byte-for-byte. No change to foreign-server artwork is included in LuaHZ.

The v1.6.1 upstream release advertises custom splash screens; upstream issue [393](https://github.com/openmultiplayer/launcher/issues/393) reports intermittent loading-screen failures. That report is context rather than proof of the cause in this setup.

### Earlier integration trial

On 2026-10-13 the owner accepted the isolated open.mp 1.6.1 trial with native client build 6 and verified SA-MP R5: custom loading artwork, centered loading bar, HUD hiding over the F9 browser, and responsive F12 settings. The owner also launched the existing classic SA-MP R5 Base Test and confirmed both work.

The tested Lua files and native helper were promoted into source/player inputs. The existing classic installation was kept unchanged during that initial trial; it used its prior native helper. The subsequent exact RC checklist above covers the combined helper in both installations. No new player ZIP has been published; the published 0.4.0 archive predates these changes.

## Setup and choice

open.mp supplies SA-MP clients plus its own native client component. Select the verified managed **0.3.7 R5** or the matching client from the GTA folder. Other SA-MP versions are outside the current native/SAMPFUNCS support boundary.

open.mp uses **F9** for its browser. In LuaHZ settings (`/luahz`), choose **F12** or another available settings shortcut. The classic default remains F9; user preferences are never automatically rewritten. When using an isolated Windows profile, launch through that profile's wrapper so settings/favorites remain in the intended profile.

## Implementation boundary

- A read-only, HZ-only adapter recognizes build 6 metadata and the browser flag's exact instruction signature. It hides the HUD while the browser is visible. Unknown builds retain the ordinary input/render path.
- Windows settings-key polling supplements missing window messages. Both arrival orders are deduplicated, preventing one press from opening and immediately closing settings. Typing, focus, modifiers and browser guards remain in force.
- The early loading helper retains the classic SAMPFUNCS getter ABI. For the verified open.mp splash hook, it decodes fingerprint-approved artwork into its own dictionary, initializes GTA sprite rendering, and draws without replacing stock/open.mp texture references. Owned SAMPFUNCS substitutions are bypassed for this renderer.
- The centered bar uses a signature-checked saved GTA trampoline. Foreign/disconnected peers use the retained open.mp renderer and restored bar operands. Fresh foreign/unknown startup starts no loading worker, reads no artwork and installs no patches.

Standalone Lua/native fixtures cover gates, signatures, ownership, sprite initialization, bar restoration, stale operands and both key-arrival orders. They do not prove live graphics or the complete server-switching matrix. Local receipts retain tested hashes and rollback files outside public source.

## Remaining owner checks before a player release

1. Verify the publication repackage preserves all 694 tested game files and obtain owner acceptance of the changed documentation/source metadata under the release guide's exact-archive rule.
2. Retain the foreign-server black-splash baseline limitation above. Further diagnosis is separate from the passed checklist. Linux CI is source/build/recovery verification; Linux/Wine owner gameplay QA remains the previous 0.4.0 result.

## Primary references

- [open.mp launcher downloads and changes](https://open.mp/downloads/launcher)
- [1.6.1 client selection](https://github.com/openmultiplayer/launcher/blob/v1.6.1/src/utils/game.ts)
- [1.6.1 R5 checksum](https://github.com/openmultiplayer/launcher/blob/v1.6.1/src/constants/app.ts)
- [1.6.1 client injection](https://github.com/openmultiplayer/launcher/blob/v1.6.1/src-tauri/src/injector.rs)
- [Plugin-SDK sprite drawing API](https://github.com/DK22Pac/plugin-sdk/blob/master/plugin_sa/game_sa/CSprite2d.cpp)
