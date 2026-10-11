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

## Command observations — local 0.2.43

The original 0.2.42 experiment remains archived. After the owner confirmed stability with SilentPatch, 0.2.43 reintroduces event-only observations with an explicit read-only request path: `/luahzcapture families|rules|members|info|settings|myguns|help` queues one request in the main loop, arms the recorder before sending, and automatically finishes eight seconds later. It never sends action commands or `/buylevel`. The earlier header-only captures do not establish why outgoing command events were absent; this direct path removes dependence on that event for its own request framing. Capture files now include a terminal reason when limits/write errors permit.

The Horizon page observes received login textdraw events to report a version; it does not authorize the endpoint, query a remote service, enforce compatibility restrictions, or prove every server helper is supported. A standalone `V2.4.47[Z]` needs a Horizon login title in the session; complete `HZ:RP v2.4.47(z)` labels normalize to the same display. Unknown formats remain unknown; different observed versions produce an ambiguity status. No native textdraw string getter or slot scan is used for version detection. The 0.2.41 native scan was removed after the owner reported loading freezes; no Lua error established the cause. Reload may leave the version unknown until fresh events arrive, normally on reconnect. Hidden banner observations remain available for the current session, then reset on disconnect/restart.

`/luahzcapture on` enables explicit local diagnostics after login. Only argument-free commands from the discussed allowlist open eight-second capture windows: `/buylevel`, `/pvl`, `/pvlock`, `/gvl`, `/rules`, `/families`, `/myguns`, `/settings`, `/killcheckpoint`, `/members`, `/info`, `/help`. Manual observation mode generates no request; the explicit read-only path described above sends only the command the owner requested. Other outgoing commands end the window without recording their text. Password-style or password/login/register-titled dialogs are excluded; dialog responses and user input are never captured. Other server traffic can overlap an allowed window, so every incoming record is a candidate rather than asserted command output.

Capture stops after five minutes, 30 requests, 512 records, or 128 KiB, and a response window stops after 96 events. Text is limited to 8192 bytes per event, with explicit truncation; other strings to 256 bytes. JSONL maps raw SA-MP text bytes to Unicode codepoints 0–255, preserving arbitrary encodings without assuming UTF-8 (a consumer can encode the parsed string as Latin-1 to recover original bytes). Files are flushed per record and remain in the owner's game config directory. They can contain personal account information and must not enter public source/fixtures without review and anonymization.

The runtime rechecks endpoint authorization for callbacks/commands. It closes capture on focus loss, disconnect, gamemode restart, reload or termination. Capture never automatically resumes. Write errors stop this observer without disabling the existing server-response handlers. Live response timing, exact version textdraw format and captures remain owner QA work.

## Horizon information snapshots — local 0.2.44

`server_info.lua` maintains session-only structured responses for `/families`, `/members`, `/rules`, `/settings` and `/info`. F9 refresh explicitly queues one of these five commands through the existing main-loop sender; it does not poll. Recognized headers can also observe normal server responses when an outgoing-command callback is unavailable. Family rows require ID/name/leader/member/online structure; member name boundaries use the received color delimiters and ranks remain group ranks. Rules recognize the nine titles and summary footer captured on 2.4.47 [Z]. Settings recognize eleven On/Off values and the server command list; community links are restricted to the five observed Horizon targets and exposed as clipboard actions. Unknown/incomplete formats are not fabricated. Normal chat is never hidden by this model.

Rows without a server-supplied total are presented as received snapshots rather than a completeness guarantee. Refresh retains old data on failure, marks recognizable partial responses, and shows age. All pages reset on session exit; no diagnostic files or cached private account responses are loaded from disk.

Remaining respect is passively observed from the exact server sentence after ordinary manual `/buylevel` usage. It is never requested for data collection, no level formula is invented, and the remainder clears after a changed `/stats` level/respect snapshot. The `/myguns` captures establish a timestamp and an unidentified integer, not X/Y/Z coordinates; no gun map adapter is provided.

## Refresh visibility — local 0.2.45

Only the sender for an explicitly queued Server-tab Refresh marks its response quiet. `server_info.lua` returns a hide decision for positively recognized headers/rows/footers inside that bounded request. Other chat, announcements, errors and malformed/mixed lines pass through. A one-use, one-second outgoing echo token preserves that ownership when SAMP.Lua reports the send after the sender returns. Chat Enter for a slash command and explicit custom keybinds revoke the token before a manual outgoing callback; manual replies and diagnostic captures remain visible. Tokens clear on consumption, expiry, send failure or session reset. Snapshot parsing and hiding are separate: partially recognized data can still be retained while the unrecognized line stays in chat. The native incoming callback suppresses only successful recognized-owned decisions. No global chat filter is added.

## Command help and paired bindings — local 0.2.48

Commands separates LuaHZ’s registered shortcuts from a searchable session-only `/help` response. The server’s `*** CATEGORY *** /command ...` rows retain categories, aliases and notes; unknown/malformed output remains visible and missing rows are not invented. Refresh shares the existing bounded info request ownership and missing-job inference. Search/display never submits a listed command. `/help` is also allowlisted for explicit read-only diagnostics.

Custom bindings keep their original command and can store one optional validated second command. Vehicle locks preset uses the owner-confirmed distinct personal `/pvl` and group `/gvl` toggles; it does not infer ownership or force a shared lock state. Two-second spacing permits each observed banner to display, but server cooldown behavior remains live QA. Unsent steps cancel rather than resume after loss of input/gameplay eligibility. Original server feedback stays visible.

## Smart lock fallback — local 0.2.49

An exact personal (`/pvl` or `/pvlock`) and group (`/gvl`) command pair is recognized independently of its saved name or key. Its own first request waits for a colored vehicle `Locked`/`Unlocked` textdraw banner or the captured exact scope-specific nearby failure. Success stops; only that nearby failure permits the other scope. Expected primary failure is hidden only for this active owned fallback, while final errors/manual replies remain visible. A three-second unconfirmed response stops instead of assuming failure. Eligibility loss, manual commands and session cleanup still cancel pending steps. The observed native/banner state is not an ownership database and no game/server field is written. Other two-command bindings keep their original sequence semantics.

## Owned lock-result notice — local 0.2.50

After the exact two scope failures of a LuaHZ-owned fallback, the final near-vehicle chat error is replaced with one keyed toast. Manual/unowned errors are unchanged. Repeated results refresh the queued/current notice instead of stacking; notice expiry remains bounded. Timeouts use this same presentation without sending another command. The owner confirmed the earlier repeated chat rows corresponded to multiple key presses.

## Quick Actions — local 0.2.53

GUI actions use existing ordinary server commands/mod controllers and execute once after the panel closes. Player rows are a client snapshot; ID/name identity is checked again before /find. Input/dialog/focus/death/session guards cancel pending UI work. The detective permission is decided by the server; no player role/state is changed. /killcheckpoint is an owner-clicked action, never a periodic data fetch. Until its exact reset acknowledgment, navigation request traffic is paused and no successful cleanup is claimed. Confirmed cleanup removes only local transient trackers/checkpoint/queued navigation and taxi accepts; persistent places and unrelated settings/offers remain. Manual server reset acknowledgments also stop local tracking.
