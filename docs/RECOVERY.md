# Deployment and recovery

Always close GTA and SA-MP before native recovery. Tools verify current/backup hashes and reject unrelated changes. Receipts are in the selected game's moonloader/config directory; original and previous working payloads are in dated game backup folders. Keep them with that installation.

- Lua source update: tools/deploy.py update --moonloader <folder>. Previous sources are stored in Horizon Base backups. restore returns to the original pre-LuaHZ installation, not automatically the immediately preceding source version.
- Native font/icon/map prototype: tools/native_visual_assets.py restore --game <folder> verifies original baseline and retained working assets, restores the preceding global-visual arrangement, and disables the prototype resource folder. That is recovery, not HZ-only distribution.
- Early loading selector: tools/native_loading_startup.py restore --game <folder> removes/disables the startup selector and restores the preceding global splash/bar binaries. Artwork update rollback retains the prior matched helper/resource pair and receipt in the startup backup's updates directory.

Legacy native_fonts.py, native_icons.py, native_radar.py, native_loading_bar.py and sampfuncs_loading.py describe older local preparation/global modification routes. Their receipts may be superseded by the runtime/startup receipts, so hash guards can intentionally refuse those older commands. Do not bypass guards or combine old global modifications with the current shared-server setup. native_loading.py is a legacy filename-redirect experiment bypassed by SAMPFUNCS, retained only for historical recovery tests.

When an update fails, the transactional tool restores only what it changed. If hashes no longer match, inspect the receipt/backup and external modification before acting; preserve the affected files. Do not run a broad restore, delete the game folder or replace prerequisites to fix a single Lua/rendering issue.
