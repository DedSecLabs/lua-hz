# QA and accepted coverage

## Accepted baseline

The user performs in-game visual/gameplay QA. Reported normal-launch HZ → another server → HZ tests passed for the Lua gate (0.2.30), native fonts/icons/maps (0.2.32) and loading screen/bar (0.2.33). Those tests used one SA-MP browser/installation under Wine and were repeated. The approved loading artwork before the current edit is v8. Native Windows, arbitrary other mods/client builds and separate same-process splash redisplay are not claimed as tested.

## Accepted 0.2.35 artwork

The owner confirmed the 0.2.35 in-game test is complete on the existing Wine installation. The user-supplied artwork is copied unchanged at 1672×941; the accepted 2048×1024 uncompressed native format remains. No endpoint/rendering logic changed. This approval is separate from fresh installation of a downloaded player package, which remains untested. Follow [player installation QA](PLAYER_INSTALL_QA.md) for that test.

## Regression cases

- Other-server initial launch: no LuaHZ HUD, menus, commands, automation or enhanced/native artwork activation. Unknown peer/wrong port/lookalike names remain inactive.
- HZ login, script reload, temporary ped loss and reconnect: native HUD handling, fresh status/login data, no stale queued actions, no duplicate UI subscriptions or held cursor/control/weapon-cycle locks.
- Character Status: native portrait/ID, live health/armor/cash, tabs without repeated headings and Refresh below portrait metadata; only recognized own-character snapshots are suppressed.
- HUD/dashboard: health normalization, stable MPH width, icons/bars, stamina/oxygen priorities, scaling/position, readability at normal resolutions.
- Quickmap/native map: sprites, saved HZ observations, streamed tiles, owned-blip cleanup, native pool budget, zoom/pan and active zone colors.
- Native graphics: HZ enhancements, original appearance elsewhere, alt-tab/device reset, travel/streaming and unload/reload. Preserve logs if a native helper fails closed.
- Server automation: current messages/dialog variants, price/cooldown guards, typing/pause/focus suppression and command collisions. All actions use ordinary server commands; no health/ammo/account mutation.

## Offline evidence

Run tools/check.py for syntax, fake-runtime Lua behavior, native C ownership/policy and Python preparation/deployment/rollback fixtures. Optional --moonloader validates exported API/event names. Standalone Wine probes exercised real native DLL/ASI loading, resource validation and the loading getter ABI without launching GTA. Fresh-source verification clones an audited source export, runs checks with no private files/game, and compiles both native components. These checks complement the user’s live tests; they do not prove rendering/network correctness themselves.

Activation, hashes, backup paths and test logs are recorded in ignored build/ and game receipt files. STATUS.md is the concise current handoff; historical experiment notes are archived privately.
