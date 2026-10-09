# Architecture

## Runtime layers

HorizonBase.lua is the minimal MoonLoader entry point. server_gate.lua reads native availability, connection state and exact IP/port. It lazily constructs runtime.lua only on the approved endpoint. The runtime owns configuration, server events, UI, overlays, commands, game sampling, native locations, limiter and visual helper. On leaving HZ it unregisters callbacks/commands, drops queued traffic, closes panels, releases controls, restores script/native visuals and resets login/status data. Cached modules are inactive after an HZ session; a fresh other-server launch never loads them.

config.lua validates/imports preferences; logic.lua contains pure parsing/calculations. game.lua reads native player/vehicle state and owns cruise/reload control through ordinary APIs. server.lua queues normal server commands and parses responses; character.lua separates account snapshots from live native fields. DATA_SOURCES.md describes those boundaries. location_catalog.lua owns the persistent HZ observation cache. native_locations.lua adds only owned saved blips within the native pool budget.

ui_backend.lua is the credited MIT mimgui adapter with independent activation checks and font fallback. ui.lua renders settings; character_ui.lua renders portrait/tabs; overlay.lua renders the HUD and Quickmap; dashboard.lua and bitmap_font.lua/hud_glyphs.lua handle dashboard/font geometry. toast.lua owns the bottom-right load/status notification. Texture warmup is bounded across frames. server_hud.lua restores only retained HZ textdraw positions and discards stale state when server identity is lost.

## Native layers

native/visuals.c builds LuaHZVisuals.dll. native_visuals.lua loads it with LuaJIT FFI only inside HZ. It independently validates GTA/SA-MP and the live native peer, applies font sprite/width, radar sprite and map raster replacements, and restores only its own bindings. visual_policy.h specifies reference ownership and stream-out restoration. Original game assets remain on disk. The DLL imports only KERNEL32.

native/loading.c builds LuaHZLoading.asi, a minimal early selector through the existing ASI loader. loading_policy.h parses an unambiguous launch endpoint. Other/unknown launches return without resources, worker or patches. On HZ it validates supported binaries and the artwork fingerprint, redirects the SAMPFUNCS resource call with the verified EDX/stack ABI, selects full-screen rendering and adjusts the native live bar in memory. Live peer monitoring disables custom rendering after leaving. Original GTA/SAMPFUNCS files stay stock. No native game/plugin code is bundled.

## Tooling and ownership

tools/check.py runs Lua syntax/behavior, native C policy/ownership and Python transactional deployment tests; --moonloader adds local API-name verification. Native builders compile original C without a CRT dependency. deploy.py stages/installs only the LuaHZ namespace with backups. native_visual_assets.py separates verified local assets and restores the original five game asset files. native_loading_startup.py owns the early loading selector, its paired encoded artwork and recovery. Legacy native_radar/fonts/icons/loading tools support historical preparation/recovery; do not use them to reintroduce global modifications into the shared-server setup.

src/, native/, tools/, tests/, approved Lucide assets, the README/menu logo and current docs form public source. .local/, build/, branding/, game installs, original inputs and toolchains are local-only. docs/ASSETS.md and manifests describe external inputs; SOURCE.json and deployment receipts record exact local bytes. The source-only export never includes game executable/plugin binaries or personal preferences/logs.

Release packaging is separate from game deployment. package_release.py combines an audited source export with explicitly named x86 native builds and emits a developer-preview ZIP, per-file manifest, release notes and checksums. release.yml verifies the payload and creates drafts only on main; pull requests have no release write access. It never reads the game or local QA archive, and player packaging is explicitly disabled pending complete resources/installation QA.
