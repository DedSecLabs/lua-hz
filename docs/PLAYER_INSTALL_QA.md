# Test installation as a new player

The existing 0.2.35 artwork build passed the owner's in-game test. This test answers a different question: can someone with a clean compatible game install the public download by following only the README and package instructions?

The owner selected a separate Linux/Wine game copy. Native Windows coverage remains a separate task. The owner launches the game and performs gameplay/visual checks; offline inspection alone does not establish a successful installation.

## Published preview inspection

The public v0.2.35-source-preview download was fetched from GitHub Releases. All three attached-file checksums and all 139 ZIP payload hashes matched. It contains 136 source files, START-HERE.md and two compiled helpers. UI icons and the project logo are included as source assets.

The ZIP is a developer layout, not the game layout. It does not contain deployed moonloader/resource/horizonbase folders or the matched loading.enc. The native builds alone cannot reproduce the working game's appearance. The inspection stopped before installation; no game files were changed. This is an identified blocker, not a completed live clean-install test.

## Resolve the player payload

Inventory every resource needed for the intended player experience using [ASSETS.md](ASSETS.md) and manifests/assets.json. For each group, record its source, hashes, destination and distribution terms. Include resources when redistribution is supported, provide a reproducible acquisition/preparation path when appropriate, or choose an approved replacement. Do not silently drop a feature or advertise the sparse developer package as the complete mod.

The player ZIP must contain the Lua entry point/modules, licensed UI resources, required visual groups and correctly paired native helpers/resources. It should provide a short start-here guide and a first-install/update path with supported-build checks, backups and rollback. It must not include GTA files, player preferences, account data, logs or unrelated mods. Prerequisites remain separate downloads.

The existing SAMP.Lua baseline requires manual editing. Before claiming a beginner installation, provide a verified way to apply that adjustment without asking players to edit code, retain upstream notices, and test that path.

## Clean Linux/Wine procedure

1. Use a separate, lawful classic GTA SA 1.0 US copy. Record its starting state. Do not copy the current modded game and call it vanilla.
2. Use an isolated Wine prefix for this test to expose runtime dependencies supplied by the working environment. Keep the existing game/prefix unchanged. Record the Wine runner, prefix architecture and any installed system runtimes or overrides.
3. Follow the README prerequisite table in order. Download the named versions, install them into this game copy within this prefix, and record any browser challenge, missing file or unclear step. Confirm SA-MP can join Horizon before adding LuaHZ.
4. Download the candidate player ZIP from its actual release URL into a new folder. Verify its checksums. The published developer preview currently fails the complete-payload requirement; do not fill its gaps from the working installation.
5. Follow only the included player guide and installer. Record every extra action or unexplained choice. Installation must validate the target, avoid unrelated files and create recovery records. Confirm there are no absolute owner-machine paths in the payload.
6. The owner starts Horizon and checks the notification, F9/settings, Quickmap, Character Status, HUD/fonts/icons, cruise controls and loading artwork/bar. Exit fully, launch another server and confirm stock behavior, then exit and return to Horizon.
7. Change a setting/save a location, then test update and recovery using candidate packages. Verify settings, saved locations and unrelated files survive; keep the original backup until recovery is checked.
8. Record the result, package/source hashes, prerequisite versions, runtime setup and actual platform tested. Every undocumented action becomes a documentation or installer fix; repeat the affected steps with a fresh baseline.

## Completion criteria

The test passes when the downloaded package reproduces the intended features on the clean game using only published prerequisites and the included instructions, with no compiler, private asset folders or Lua editing required. Update/recovery must preserve user data. Keep Windows support explicitly pending until the Windows clean-install test passes.
