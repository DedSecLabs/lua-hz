# open.mp compatibility and QA

LuaHZ offers launcher choice with the same supported GTA SA 1.0 US, SA-MP 0.3.7 R5 and verified R5 SAMPFUNCS fingerprints. open.mp launcher versions and SA-MP client versions are separate.

## Accepted local Windows result

On 2026-10-13 the owner accepted the isolated open.mp 1.6.1 trial with native client build 6 and verified SA-MP R5: custom loading artwork, centered loading bar, HUD hiding over the F9 browser, and responsive F12 settings. The owner also launched the existing classic SA-MP R5 Base Test and confirmed both work.

The tested Lua files and native helper are promoted into source/player inputs. The existing classic installation was kept unchanged during the comparison; it used its prior native helper. Running the combined helper in that classic installation, the complete Windows feature checklist, and in-process server switching remain separate QA items. No new player ZIP has been published; the published 0.4.0 archive predates these changes.

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

1. Run the combined helper through classic SA-MP R5, then verify the exact final player archive.
2. Check native fonts/icons, Quickmap, Character, Quick Actions, Vehicle, input/mouse behavior and preference persistence on Windows.
3. Switch HZ → another server → HZ using open.mp's browser; verify Lua/native deactivation, original foreign-server visuals, canceled queues and clean reactivation.
4. Start fresh on another server, then join HZ without restarting; distinguish startup-only artwork from reconnect presentation.

## Primary references

- [open.mp launcher downloads and changes](https://open.mp/downloads/launcher)
- [1.6.1 client selection](https://github.com/openmultiplayer/launcher/blob/v1.6.1/src/utils/game.ts)
- [1.6.1 R5 checksum](https://github.com/openmultiplayer/launcher/blob/v1.6.1/src/constants/app.ts)
- [1.6.1 client injection](https://github.com/openmultiplayer/launcher/blob/v1.6.1/src-tauri/src/injector.rs)
- [Plugin-SDK sprite drawing API](https://github.com/DK22Pac/plugin-sdk/blob/master/plugin_sa/game_sa/CSprite2d.cpp)
