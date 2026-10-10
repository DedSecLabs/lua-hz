# Character and gameplay data sources — 0.2.22

Prefer a documented MoonLoader/SA-MP getter for live data already present on the client. It avoids chat requests and returns the current rendered state. Keep server commands for server-only RPG/account information, remote entities outside streaming, and actions whose rules the server controls. A native API is a client observation, not a replacement for the server's authority.

| Data or feature | Preferred source | Reason / current implementation |
| --- | --- | --- |
| Skin, player ID, nickname | getCharModel / sampGetPlayerIdByCharHandle / sampGetPlayerNickname | Current local ped and existing SA-MP identity; no command. Avatar follows the model while I is open. |
| Health, armor, displayed cash | Existing Game sample / native getters | Live Character Status values. Health retains LuaHZ's already-tested Horizon display conversion. Cached /stats fields remain intact. Cash reflects GTA's currently displayed client balance. |
| Stamina, oxygen, position, heading, weapon, GTA stars, game clock | Existing native reads | Already native; no new request. GTA wanted stars are not substituted for Horizon's Wanted Level record. |
| Vehicle speed, condition, name/model, lock, cruise state | Existing native getters / local state | Already native; lock is observed instead of polling /pvlock. Native observations do not change ownership/locks/ammo. |
| Level, hours, character age/gender, phone, warnings, respect, upgrades, donator | Horizon /stats snapshot | Client model appearance is not RPG identity; scoreboard score is not assumed to mean account level. |
| Job/job2, faction, rank, division | Horizon /stats snapshot | No reliable general client getter for Horizon's account records. |
| Bank, total wealth, insurance, marriage | Horizon /stats snapshot | Displayed cash alone cannot establish bank or total wealth. |
| Spawn armor, crimes, arrests, server Wanted Level, radio | Horizon /stats snapshot | Server records may differ from native gameplay fields. |
| Materials, drugs, packages, crates and other RPG inventory | Horizon /stats snapshot | Not the native GTA weapon inventory. |
| Screwdriver, wristwatch, tire, first aid, receiver, GPS, bug sweep, lockpicks | Horizon /inv snapshot | Sent once after each /stats request. A manual /inv updates the same fields. |
| /find, /trackcar | Normal server commands | Server-authorized last-known/remote locations; local coordinates only exist for entities in range and don't reproduce detective eligibility or saved vehicle selection. |
| /accept offers, /reload 2 | Normal server actions | Requests a server-controlled transaction/animation. A native getter cannot replace the action. |
| Map POIs | Observed server icon events + existing local catalog | Active native/SA-MP pools contain received markers. They cannot enumerate unseen server locations. The cache retains locations that streamed out. |

Character Status still makes the existing one guarded /stats request after successful login; Refresh still has a ten-second gap. There is no periodic account polling. Live fields and avatar add no commands. This build does not claim a reduction in the existing login request count, because the remaining account fields still require that response.

## Native ESC map

Remembered locations missing from the live icon set are added as client-owned coordinate sprite blips only while the ESC menu is active. The bridge avoids current native/live locations, then removes only its own valid handles on return to gameplay, disable, disconnect or reload. No server icon slot or server packet is modified. The regular radar remains its existing live display.

The GTA native pool has 175 trace slots; LuaHZ reserves 32 free slots for game/server use. If the available budget cannot fit all remembered candidates, the nearest known locations are selected and diagnostics report how many were limited. Quickmap retains the entire local catalog. This adds all known locations that fit, rather than fabricating a server-wide list. Native game icon/area filters may still apply and need live testing.

The setting is Quickmap → Native Map Locations, enabled by default. It also requires Remember Locations, successful Horizon login, and the current session. /luahzdebug reports last_menu_shown and last_menu_limited so the user can capture results after closing ESC.

References: [skin gallery](https://open.mp/docs/scripting/resources/skins), [SA-MP event fields](https://github.com/THE-FYP/SAMP.Lua/blob/master/samp/events.lua), [native radar layout and capacity](https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/Radar.h), [blip opcodes](https://github.com/SannyBuilder/library/blob/master/sa/sa.json).
