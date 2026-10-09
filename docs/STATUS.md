# Current status

Accepted baseline: 0.2.33. The user repeatedly tested HZ → another server → HZ with one SA-MP browser/installation and confirmed scripted features, native fonts/icons/maps and loading artwork/bar behave as intended. Approved artwork before the new request is mosaic v8. These are reported normal-launch tests on Linux/Wine; native Windows and separate same-process reconnect coverage are not claimed.

Current work: 0.2.35 replaces the loading artwork with the user’s supplied GTA-style PNG (mosaic v10), copied byte-for-byte at the same 1672×941 dimensions. Native packaging remains 2048×1024 uncompressed A8R8G8B8. No imagegen or creative editing is used. The source/handoff work from 0.2.34 remains; the new artwork’s in-game QA is pending.

Verified: offline Lua/Python/C tests; real Wine native-helper ABI/resource probes; original-game fallback and installer rollback checks; user-approved normal-launch isolation. The public source repository is [DedSecLabs/lua-hz](https://github.com/DedSecLabs/lua-hz). No public player release or remote update service exists yet. LuaHZ has its own standalone local Git repository; source-export/clone tests use a separate temporary repository.

Publication documentation: the README now provides a player-facing overview, versioned prerequisite links, installation order, controls and contributor navigation. INSTALLATION.md documents exact library reproduction, the source-only boundary and download verification limitations. The October 9 review identified mimgui 1.7.0 and the SAMP.Lua v2.0.4 material-handler adjustment, and added the ASI loader/library hashes to the dependency manifest. These are documentation/manifest changes; the installed game is unchanged.

Remaining publication decisions: rights/acquisition for external art/font/map/icon/portrait resources; which assets to replace or distribute separately; native Windows QA and release packaging. The selected repository is DedSecLabs/lua-hz (public). The core source is independent of private asset binaries for checks and compilation. Full reproduction of the approved game appearance needs those separately acquired inputs.

Data/features not proven broadly: every auto-accept/tracking server phrase/dialog variant, all client/build variants, input coexistence with arbitrary mods. The supported native builds are deliberately fixed. No server command/private account state is inferred from the cosmetic gate. See QA.md and DATA_SOURCES.md.

Historical investigations, superseded artwork/UI assets, old deployment reports and original input paths are preserved in ignored local archives with move ledgers. Current docs take precedence over those historical notes. Legacy tools remain for recovery/preparation and are marked as such in architecture/recovery docs.

README branding: the project owner requested the existing blue HZ moon logo centered beneath the title. The unchanged PNG is included in source exports with a pinned hash; other external visual assets remain excluded.

Pre-publication review: clarified the player/source boundary, defined the game folder, added troubleshooting and help instructions, corrected the SAMP.Lua section link, and documented first-install versus update commands. Native build instructions now read the real manifest fingerprint. Staging uses the included logo in a fresh source clone.

Review verification: a fresh temporary Git clone passed all 47 Python tests, the Lua suites and both native builds. The export contains 131 files, with 41 local documentation/image links checked and no broken targets. Source directory coverage, JSON manifests, export exclusions and staging of the included logo were verified. The current MoonLoader archive’s installed binary matches the recorded hash. SAMPFUNCS/HZ installer byte verification remains manual. No commit or push was performed during that review.

README controls: replaced the reload entry with mod-specific cruise shortcuts, including 1 mph adjustments and the default numpad presets. Defaults and cancellation behavior were checked against config.lua, runtime.lua and game.lua; no runtime behavior changed.
