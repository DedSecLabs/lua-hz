# LuaHZ contributor / agent instructions

Read README.md, docs/STATUS.md, docs/ARCHITECTURE.md, docs/DEVELOPMENT.md and docs/ASSETS.md before changing behavior. The repository is the source of truth; no chat history is required. Local target paths and receipts are deliberately outside public source in .local/ and build/.

## Scope and invariants

- Horizon Gaming only: native peer 213.32.6.232, port 7777. Never authorize from server names, welcome text or dialogs. Startup loading additionally accepts the exact sanctioned hostname samp.hzgaming.net. Unknown/missing/ambiguous input fails closed.
- The other-server bootstrap must not load feature modules, UI/FFI/native visual resources or register commands. Recheck the endpoint for callbacks, commands, inputs and rendering. Preserve deactivation and reconnect cleanup.
- Cosmetic/native helpers may replace owned texture references, rasters and font widths with verified restoration. Do not write player health, armor, cash, ammunition or server state. Commands remain ordinary documented server commands.
- Native code supports only the verified GTA SA 1.0 US / SA-MP R5 / SAMPFUNCS build. Preserve exact metadata/signature/hash checks, texture reference counts and stale-owner guards. Unknown versions keep the original game behavior.
- Original game/plugin files stay stock on disk. Native font/map replacements are separate resources and active only on HZ. The early ASI is only a startup selector; no artwork read, worker or patches on another/unknown launch.
- Never update a loaded native binary or texture. Native deployment requires closed GTA/SA-MP, prepared payloads, verified backups, change guards and rollback. Preserve settings, saved locations and unrelated files.
- User performs in-game visual/gameplay QA. Do not automate gameplay, launch another account or claim offline tests prove live rendering. See docs/QA.md for the actual verification scope.
- Image edits use imagegen unless the user explicitly selects another method. Keep unchanged panels/title/footer and sharp detail; game textures use 2048×1024 uncompressed A8R8G8B8. Save prompts and provenance locally. Loading bytes and helper fingerprint update together.
- Keep third-party assets/binaries and personal files outside public source. Consult asset manifests and notices. Attribution is not permission; do not include pending-rights assets in a release.

## Workflow

1. Inspect the module and relevant tests; use rg for search. Keep changes focused and update current docs when behavior changes.
2. Run `python tools/check.py --luajit /path/to/luajit`. For native changes also build the relevant component and run ownership/policy tests. Optional `--moonloader` checks API names against a locally installed runtime.
3. Use tools/deploy.py for backed-up Lua deployment. Native installers and artwork updater have their own receipts and recovery paths; see docs/DEVELOPMENT.md. Use the ignored .local/active-qa-target.json only on the owner's machine, never hardcode it into source.
4. Update docs/STATUS.md: accepted baseline, current pending QA, material limitations. Record local activation/verification in ignored build/ receipts.
5. Before publication, run tools/export_source.py and tools/verify_source_clone.py. No game installation or private art is needed for source checks/native code compilation; full visual deployment requires external assets.
6. Do not publish a player release until the owner has launched that exact build and confirmed the changed behavior.

Do not remove historical work irreversibly: archive obsolete local experiments under ignored .local/archive with a move ledger. Keep legacy recovery tools until documented backups are retired. Do not create additional agents unless the user requests delegation.
