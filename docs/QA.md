# QA and accepted coverage

## Local 0.2.54 Quick Actions alignment

The owner’s 0.2.53 screenshots show the grid/icons working, with status rows slipping to the window edge and Find/Back/Refresh players using inconsistent positions/heights. All affected text rows now explicitly share the 22-unit inset. The selector label and full-width input sit above an explicit button row; Find/Back/Refresh use a 28-unit height, and Refresh is concise, right-aligned and secondary-colored. The player list starts below that row. No server-action behavior changed.

Launch Base Test and confirm 0.2.54. Open U and check both tracking status lines align under the checkpoint status. Enter Find player; title, detective hint, name/ID label and field should share the left margin. Find/Back and the right-aligned Refresh should have matching top/bottom edges, with Refresh visibly distinct. Check filtering, Refresh, Back and selection still work. Test at the owner’s usual UI scale; broader Quick Actions gameplay checks from the section below remain open. The regression uses native-style cursor reset in the UI harness; live pixels remain owner QA.

## Local 0.2.53 Quick Actions

The owner approved four functions in a compact U panel: clear navigation, smart vehicle locking, vehicle tracking and find player. It uses Lucide map-pin-off, lock-keyhole, radar and search icons. The Find player selector reads the client’s online list on opening/explicit refresh, filters locally and revalidates the selected ID/name before submitting; typing in its field must not trigger I/U shortcuts. Server detective permissions remain authoritative. Actions close the panel and execute once in the main loop. U migration must preserve pre-existing shortcuts by leaving Quick Actions unset on collision; /luahzactions remains available.

Launch Base Test and confirm 0.2.53. Open U, check the 2×2 grid/status/icons, then close with Escape/U/X. Verify typing, dialogs, focus loss and holding U do not cause unwanted actions; find-mode U/I should type normally. Compare smart-lock behavior with the accepted shortcut. Track my vehicle should open the usual server selection when needed; reopening U should offer Stop vehicle tracking. Find player should accept a known online name/ID or listed player, show the detective requirement and provide Stop finding when active. Test unavailable/changed targets and job denial without unexpected requests. Stop controls stop LuaHZ updates; the existing server checkpoint remains until Clear navigation.

With local finding/tracking active and a server checkpoint, click Clear navigation once. Expect one server request, then a success toast only after the exact reset acknowledgment. Reopen U and check both local trackers are off and the transient checkpoint is absent. Old queued find/cohort/track/taxi requests and pending tracking dialog replies must not recreate navigation; saved Quickmap places and unrelated preferences/offers must remain. A timeout/unconfirmed response must not be presented as a successful clear. Manual /killcheckpoint confirmation also performs local cleanup while its chat reply stays visible. Observe ordinary manual replies/unrelated server traffic and foreign-server inactivity.

Offline tests cover request deduplication, bounded acknowledgment/timeout, exact message framing, paused navigation traffic, preserved POIs/unrelated offers, UI selector/error cleanup, U collision migration and actual entry-point input/action flows, including target identity changes. No live game automation is performed. Owner gameplay/visual QA is pending.

## Local 0.2.52 equal-width notices and labeled energy panels

The owner’s 0.2.51 screenshots show the notice above stamina but with a wider, misaligned card. Stamina/oxygen width is now 368 logical units, 15% above the original 320; height/icon/bar geometry is retained. Stamina/Oxygen text is right-aligned in the icon row above the bar, using the normal UI font. Toasts share this energy layout’s physical width, minimum height and right edge at the current HUD scale, even when the energy panel is temporarily hidden. Native vehicle dashboard width is unchanged.

Launch Base Test and confirm 0.2.52. While running, compare the login or lock-result notice and stamina: both left/right edges and widths should align, with a clear vertical gap. Stamina should appear at the right of the icon row above the bar. Repeat with on-foot oxygen or submerged-vehicle oxygen when convenient, verifying its label and retained stacking above full/minimal vehicle information. Change HUD size and check matching width/edge alignment; the shared viewport clamp should prevent clipping on smaller screens. Longer notices may wrap and grow vertically. Existing functionality and saved preferences should remain intact.

Offline drawn-geometry tests cover width/edge equality, shared short-notice dimensions, label content/right alignment/bar clearance, and viewport bounds across four resolutions, three HUD scales, all dashboard modes and five activity states. Existing startup/keyed-notice tests remain covered. The owner reported “Looking good” after testing 0.2.52, accepting this presentation; exact submerged-vehicle/viewport combinations were not specified.

## Local 0.2.51 unified notifications above the lower HUD

The owner reported 0.2.50 tests positive, but running screenshots show the toast overlapping stamina. All notices now share the same larger card/typography/icon layout, including the login load notice. Dynamic clearance uses the exact currently applicable dashboard/energy panel geometry, independent of previous draw order; hidden/disabled HUD panels do not leave phantom gaps. Existing oxygen-above-vehicle geometry is preserved.

Launch Base Test and confirm 0.2.51. Compare login and lock-result notices for matching width, minimum height, typography, icon size and padding. Trigger a no-nearby lock result while stamina is visible: the toast must sit above it with a gap. Check on-foot oxygen, full/minimal vehicle HUD and submerged-vehicle oxygen plus dashboard when convenient. Disabling stamina/oxygen/dashboard should reserve only the panels still shown; when none is visible the toast returns to its bottom anchor. Check Quickmap, UI/HUD size changes and narrower resolutions as practical. Repeated lock attempts should still refresh one notice.

Offline layout tests compare drawn toast bounds with actual dashboard/energy rectangles across four resolutions, three HUD scales, all dashboard modes and five activity states. They cover shared login/action sizing and typography, viewport fit and disabled/hidden panel handling. Runtime and keyed-notice expiry/deduplication suites remain covered. Live rendering remains owner QA.

## Local 0.2.50 quiet no-nearby lock notice

The owner reported the 0.2.49 layout and smart locks work. Multiple final family-vehicle errors came from multiple presses, as clarified by the owner. Local 0.2.50 replaces only the exact final failure of an owned personal/group fallback with a keyed bottom-right warning. Repeated attempts update that notice instead of adding more chat messages or queued notices. Manual /pvl and /gvl replies are preserved. A missing response also uses the action notice, retaining the no-speculative-toggle behavior.

Launch Base Test, confirm 0.2.50 and use the existing lock shortcut away from both vehicle types. Expect one “No personal or group vehicle nearby.” toast and no owned near-vehicle chat lines. Repeat after four seconds: the same toast should refresh. Manually issue /gvl away from a group vehicle to confirm its normal server error remains in chat. Personal/group success banners and the split editor should retain their accepted behavior. Offline tests cover owned final-failure replacement, unowned error visibility, runtime toast routing and queued/current notice deduplication/expiry.

## Local 0.2.49 smart vehicle locks and split editors

The owner tested 0.2.48 near personal-only/group-only vehicles and observed the expected scope-specific not-nearby errors. Local 0.2.49 treats a personal/group lock pair as a fallback: send the first command once; a recognized vehicle success banner cancels the second. Only the exact first-scope not-nearby message permits the fallback after the existing two-second gap; the primary owned failure is hidden, while the final failure remains visible. Unknown/cooldown/late replies never trigger a fallback. No reply within three seconds stops with a notice. Reversing the pair supports group-first behavior. The textdraw has no command request ID: attribution relies on the one active, bounded owner-issued lock request and the recognized vehicle-state format. Live Locked/Unlocked formats, delays and unrelated server traffic remain owner QA.

Launch Base Test and confirm 0.2.49. Existing personal/group lock bindings automatically use the fallback; no key reassignment is needed. Near a personal-only vehicle, press once and verify the personal success banner without a later group error. Near a group-only vehicle, verify fallback group success without the expected primary personal error in chat. Near both types, a successful first command should affect only that scope. Away from both, the final not-nearby error stays visible. Test both locking and unlocking, reversed /gvl → /pvl order if wanted, and canceled/held/repeated inputs. An uncertain or delayed response should produce no speculative second toggle.

F9 → Keybinds should open Normal keybinds, with built-in hotkeys/cruise and single-command custom bindings. Command combos should contain the saved vehicle-lock combo, preset and two-command editor. Confirm saved bindings retain their assigned chords and edits save to the correct existing row. Switching tabs abandons the unsaved editor/key capture without deleting saved data; an incomplete combo should refuse to save. Check both tab strips stay visible while content scrolls.

The 0.2.48 /help capture finished normally and received nine lines including Family and three General rows. All nine pass replay with aliases/notes preserved. No additional help capture is required for that payload. This proves receipt/parsing, not every help-tab search/render or missing-job combination.

## Local 0.2.48 command sequences and server help

The owner-directed 0.2.47 capture contains /pvl → “Bravura Unlocked” after 250 ms and /gvl → “Burrito Unlocked” after 269 ms. Their textdraw banners last 1641 and 1611 ms. Both commands were issued separately, roughly nine seconds apart: the capture does not establish a server cooldown or simultaneous-use behavior. Original feedback passes through untouched. The two-second sequence gap is conservative display spacing and needs live combined-use QA.

Launch Base Test and confirm 0.2.48. In F9 → Keybinds choose Vehicle locks preset, assign an unused key/combo and save. Close F9, stand near a personal/group vehicle you intend to toggle, and press once. Verify /pvl then /gvl responses about two seconds apart. Test personal-only, group-only and nearby mixed vehicles; their independent toggle states may differ. Hold the key and verify no repeat; try a quick repeated press and verify no overlapping sequence. Between steps, open chat/F9/I/Quickmap or lose focus: the second step should cancel and remain canceled after returning. Verify disconnect/death cancellation when practical. Compare results with manually issued commands; missing ownership/failure and server cooldowns still require observation.

In F9 → Commands, check both Server commands and LuaHZ commands tabs. Server Refresh should show the current /help categories and aliases after the bounded response window, support search and leave unrelated announcements visible. Manually issue /help to verify its normal chat visibility. Use /luahzcapture help for one explicit read-only capture so the parser can be checked against current live output. Existing missing Job 2 inference must still work. No help-list command is executed by selecting or searching it.

Offline fixtures cover optional second-command migration/persistence, validated inputs, snapshot ownership, step spacing, repeat/overlap rejection, blocked/manual/foreign/dead/expired/send-failure cancellation, actual runtime hotkey dispatch, UI preset/edit flow, help parser boundaries, deferred quiet callbacks and missing-job inference. Live gameplay/rendering is owner QA.

## Local 0.2.47 quiet Members refresh

The owner reported that 0.2.46 Members Refresh still printed to chat. Local 0.2.47 preserves GUI ownership across a deferred outgoing-command callback and removes source-command labels beside every Server Refresh button. Offline fixtures cover immediate/deferred outgoing callbacks, manual chat Enter, explicit keybind takeover, unrelated chat, token expiry, failed sends and session cleanup. Installed MoonLoader API names were checked; live delivery timing remains owner QA.

Launch Base Test and confirm 0.2.47. Open F9 → Server → Members, click Refresh and verify the roster updates without adding Members Online or roster rows to chat. Normal family chat and server announcements should still appear. After the response window finishes, type `/members` manually: its roster should appear in chat. Check that no Server information tab shows Source beside Refresh. Retain the pending 0.2.46 paired-width/long-name checks below when convenient.

## Local 0.2.46 paired menu layout

The owner’s 0.2.45 screenshots show the Server icon, tabs and family data working, but the longer family names still wrap and the tab content repeats a heading. Local 0.2.46 sets a shared 900-unit width for F9 and I, gives the Family column 40% of the table, removes repeated section headings, and keeps the Server tab strip outside the scrolling content. Character Status’s close button, tabs and field region use the new width.

Launch Base Test, confirm 0.2.46, compare F9/I width at the same UI size, and refresh Server → Families. Check Magnolia Vigilance Protection and Jefferson Shamrock Mob fit at the owner’s normal scale, while table columns remain distinct. Scroll down and verify the tab strip stays visible; switch to Status and confirm there is no repeated Server compatibility heading. Check the expanded Character Status tabs/field area/close button and smaller viewport fit when convenient. This is layout QA; no new server commands, native binaries or gameplay controls were introduced. Offline checks pass; owner live layout QA is pending.

## Local 0.2.45 Server presentation and quiet Refresh

The owner confirmed 0.2.44 information pages work and supplied families/member screenshots. Those showed visible server replies, a stale refresh warning, a dropdown and the narrower F9 layout. Local 0.2.45 changes the section to Server with Lucide’s server icon, underlined subsection tabs and a 780×540 base panel matching Character Status. Viewport fit remains enforced.

Launch Base Test and verify F9 reports 0.2.45. Compare F9 and I width at the same UI size. Open Server, switch all six tabs, and check the selected underline, icon, search labels, table wrapping and scrolling. Click Refresh on each information tab: recognized reply headers/rows should update the snapshot without appearing in chat. Unrelated conversations, paydays/announcements and unknown lines must remain visible. A successful refresh must clear the prior warning; cooldown/pending failures can still explain why another refresh was refused.

Manually issue `/families` or `/members` in chat and verify the normal response remains visible, including a manual request taking over a pending GUI Refresh when its outgoing callback is received. Diagnostic `/luahzcapture` requests remain visible. Confirm disconnect/reconnect clears quiet ownership and data. User testing of this build is pending; offline fixtures prove callback filtering/ownership and viewport calculations, not live drawing/network behavior.

## Local 0.2.44 Horizon information pages

Launch Base Test on Horizon and confirm F9 reports 0.2.44. Open Horizon, choose each information page from the selector and click Refresh. Requests may wait for the current stats response; refresh requires live gameplay and a ten-second per-page gap. Normal chat remains visible. No data from private diagnostic files is imported into the runtime, so pages start empty each session.

- Families: verify all received rows, including IDs 1 and 2, with names/leaders/counts matching `/families`. Scroll the table and test search by family and leader; long names must wrap without covering neighboring columns.
- Members: verify name/title separation, numeric family rank and rank name against `/members`. Search names/titles. The panel reports rows received, not a guaranteed server-wide count.
- Rules: verify the nine recognized rule summaries against `/rules`. Copy full-rulebook website should copy the server-supplied root website reference.
- Server settings: verify all eleven values and the command list against `/settings`. These are read-only snapshots, separate from LuaHZ HUD preferences; no toggles are sent by this page.
- Community links: verify the five links against `/info`; Copy URL must copy the displayed safe HTTPS target.
- Character Status: if using `/buylevel` for its normal purpose, check the response updates Until next level. Do not issue it just for diagnostics because it may purchase a level. It remains unknown until a matching response, and clears when observed stats change.
- Check the I/M/F9 input guards while searching, snapshot age/failed refresh, disconnect/reconnect cleanup, normal movement and the accepted oxygen fix. Preserve logs/screenshots for layout problems. Other-server and native Windows coverage remain separately scoped.

Private replay of captured responses parsed 12 family rows, five member rows, nine rule summaries, eleven settings and five links. Some diagnostic windows ended early on focus loss, so member-list completeness is not established by those captures. `/myguns` returned framing, a character header with timestamp and an unidentified integer; no coordinate or marker event appeared. Gun locations are not implemented. Offline fixtures anonymize player/family names and cover malformed/missing responses, cooldown, row boundaries, unrelated chat, safe link copying and snapshot reset. All offline checks passed; owner live information-page QA is pending.

## Local 0.2.43 direct response capture

The owner reported stable gameplay and working menus after the SilentPatch installation on 2026-10-11. Exact relaunch count and full other-server/native Windows coverage were not specified. The 0.2.43 local build retains that prerequisite and the accepted oxygen fix while restoring event-only version observation.

First launch Base Test, confirm F9 reports 0.2.43, and run `/luahzcapture families`. This explicitly queues only `/families`, arms recording before its one send from the main loop, and closes automatically eight seconds after sending. Keep the game focused until the capture-completed notice; normal server responses should remain visible. Then return to Codex for inspection of the saved file. Do not request the entire command pass until this one file contains a request, the family response and a completion reason.

The owner completed the direct `/families` capture on 2026-10-11 while keeping the game open. It contains one explicitly framed request, Gangs header, complete consecutive rows 1–12, an unrelated family chat message, window_end and capture_end (command window completed). Rows 1 and 2 were received intact. This validates the direct path for this command, not every command/format or broad client compatibility. Raw personal captures stay local; future public parser fixtures should be anonymized.

After that works, request `/luahzcapture rules`, `/luahzcapture members`, `/luahzcapture info`, `/luahzcapture settings` and `/luahzcapture myguns`, allowing each eight-second capture to finish before the next. These are explicit user-requested read-only commands, not background polling. `/buylevel`, `/pvl`, `/gvl` and `/killcheckpoint` are excluded from this sending path. Use manual capture on/off around an action only when intending to perform it.

Check expiry/cancellation while typing, paused, unfocused or disconnected, version state on reconnect, and unchanged oxygen/UI behavior. Captures stop on loss of focus, session reset or limits, never automatically resume, and record an end reason when file limits/errors allow. An overlapping outgoing command can interrupt a response window. Candidate events can include unrelated server traffic; no completeness is inferred from the window alone. Offline checks cover direct allowlist, single main-loop send, response preservation, terminal records, automatic close, action exclusion and endpoint cancellation. All Lua suites and 63 Python tests (3 skipped) passed; live capture is pending.

## Current 0.2.40 baseline and streaming deadlock investigation

On 2026-10-11 the owner reported two further login freezes after an Internet disconnect. Both the game and repository runtime were restored to exact 0.2.40 sources; 0.2.42 code/tests and local deployment experiments are preserved in ignored archives/backups. The owner then reproduced the login freeze on restored 0.2.40. A Windows-side backtrace plus channel/worker state identifies the original GTA CdStreamSync missed-wakeup deadlock, rather than proving a capture-induced freeze. Evidence is retained privately; source comparison verified all 27 installed Lua files against the accepted baseline.

SilentPatchSA 1.1 Build 34.1 is prepared from the official author release. Its archive SHA-256 was verified against the GitHub asset digest, and the ASI is x86 and imports only KERNEL32/USER32. A local INI disables optional SCM, intro-skip, sun-size and refresh-rate changes. After the owner closed GTA and SA-MP, the ASI and conservative INI were installed only in Base Test with recovery and change guards. Installed bytes were checked, all pinned prerequisites matched their hashes, and 682 existing game/source/resource/preference files were preserved. The receipt is ignored build/silentpatch-streaming-receipt.json. Repeated login, movement, F9/I/M and native visual compatibility need owner gameplay QA after installation. Start with one successful login and movement/F9 check, then verify several fully closed-game relaunches (at least three), normal reconnect behavior and the native fonts/maps/loading visuals. Inspect the log/process if any freeze recurs; do not treat one successful launch as proof of stability. No automated gameplay is allowed.

Technical references: [documented CdStreamSync deadlock](https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/CdStreamInfo.cpp), [SilentPatch streaming fix](https://silentsblog.com/mods/gta-sa/), [Build 34.1 SA-MP compatibility hotfix](https://github.com/CookiePLMonster/SilentPatch/releases/tag/1.1-BUILD34.1-SA). This is an external, local-only game prerequisite, not a bundled LuaHZ feature or a published release.

## Archived 0.2.42 observations and loading checks

The owner reported loading freezes, unresponsive F9 and player movement on 0.2.41. Its log contains a loaded notice and no Lua error before the reported failure. The native textdraw string scan was removed as the leading suspect, not a proven root cause. Recovery to accepted 0.2.40 was verified before installing 0.2.42, preserving settings/resources. Rejected sources and the session log remain in ignored backups/regression files.

On 2026-10-11 the owner reported that 0.2.42 works and remains open. The current log continues after login/load without a recorded component error. Version observation, capture behavior and repeated-launch stability still need checks.

First launch LuaHZ Base Test with 0.2.42, join Horizon, and confirm normal world loading, character movement and F9 opening/closing before enabling capture. If normal, check Horizon's observed version against the fresh-login banner. Unknown or conflicting observations must not claim compatibility. Existing features, including the accepted oxygen fix, should remain available. This stage does not disable helpers on version changes. Repeat a normal launch if needed to assess the previously intermittent failure.

First live capture on 2026-10-11 confirmed event-observed version `2.4.47 [Z]`. The file contains only its start record; the session log reports capture stopped on focus loss about 13 seconds later. No request/response was recorded, so command capture remains unverified. Retry `/families` alone without switching windows before asking for another full command pass.

Type `/luahzcapture on` after login, then manually run `/families`, `/rules`, `/members`, `/info`, `/settings`, and `/myguns`, leaving at least eight seconds between commands. Normal chat/dialog responses must remain visible. Test `/pvl` or `/pvlock` and `/gvl` separately near the appropriate vehicle types when desired. `/killcheckpoint` is an action that resets checkpoints, trackers and accepted fares: capture it only when intending that action. Do not issue `/buylevel` just for diagnostics; it may purchase a level. If manually used for its ordinary purpose during a capture, its response can be recorded.

Use `/luahzcapture off` to finish. Capture files appear under the game's moonloader/config/luahz-observations folder; the exact path is shown in chat and F9. These are private diagnostic files, not public fixtures. Eight-second windows contain candidate events, including possibly unrelated server traffic; they are not proof of complete or correlated responses. Compare `/families` rows 1 and 2 in the file with visible chat. Inspect `/myguns` for genuine coordinates or associated marker events without interpreting undocumented integers as locations.

Check capture stop on window focus loss, disconnect/reconnect, gamemode restart and script reload. It must never resume automatically. A new connection must clear version state. Version detection only observes received events, so script reload after the banner events may leave the version unknown until reconnect. `/luahzversion` reports the current observation without probing native slots. Other-server launch must retain original behavior and have no capture commands or file writes.

Offline checks cover capture opt-in/limits/errors, all 12 family rows in a fixture, sensitive command/dialog exclusions, byte-safe JSONL, ambiguous/contextual event-only version formats, UI controls/sidebar spacing and real runtime callback/endpoint cleanup through stubs. A failing native-string getter stub ensures startup never uses that API, including when textdraws exist. Successful offline checks do not establish live loading stability, response timing, banner format, renderer behavior or native Windows coverage. This build is local and unpublished; owner QA is pending.

## Local 0.2.40 submerged-vehicle oxygen check

Launch the local LuaHZ Base Test copy on Horizon and confirm F9 reports 0.2.40. With Oxygen Bar enabled, submerge a vehicle while remaining seated: the blue oxygen icon/bar should appear above the vehicle dashboard and track remaining breath. Check as a driver and passenger when feasible. Repeat with Vehicle Dashboard set to full, minimal, and off; oxygen should remain available in all three modes. Turning Oxygen Bar off must hide it. Normal driving and an upright floating boat should not show oxygen. Confirm underwater swimming still shows oxygen and surface swimming/running still shows stamina. Briefly verify another server retains stock behavior. Preserve moonloader.log if detection or drawing fails.

The offline fixtures cover the detection and dashboard combinations, API failure fallback, toggle behavior, and layout bounds. On 2026-10-11 the owner reported that the deployed oxygen fix works in game. The report does not specify every dashboard mode, driver/passenger combination, or native Windows coverage; those broader checks are not claimed. This build is local and unpublished.

## Accepted baseline

The user performs in-game visual/gameplay QA. Reported normal-launch HZ → another server → HZ tests passed for the Lua gate (0.2.30), native fonts/icons/maps (0.2.32) and loading screen/bar (0.2.33). Those tests used one SA-MP browser/installation under Wine and were repeated. The approved loading artwork before the current edit is v8. Native Windows, arbitrary other mods/client builds and separate same-process splash redisplay are not claimed as tested.

## Accepted 0.2.35 base clean install

On 2026-10-09 the owner tested published LuaHZ-0.2.35-base.zip on a separate Linux/Wine copy launched by Lutris with GE-Proton11-7. SA-MP R5 joined Horizon before the base package. After a restart from one post-login stall, the owner confirmed the load notice, settings, Character Status, cruise, a saved settings change, and HZ → another server → HZ isolation. Quickmap had no background. The custom HUD font and map pins were absent. Stock game fonts, radar and loading were intended. Native Windows, in-place update and live recovery were not part of this test.

## Accepted 0.2.35 artwork

The owner confirmed the 0.2.35 in-game test is complete on the existing Wine installation. The user-supplied artwork is copied unchanged at 1672×941; the accepted 2048×1024 uncompressed native format remains. No endpoint/rendering logic changed. This approval is separate from the later base-package clean install recorded above. Follow [player installation QA](PLAYER_INSTALL_QA.md) for that test's remaining Windows and visual-pack scope.

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

## 0.3.0 release verification

Use the exact packaged 0.3.0-rc.1 archive; keep its SHA-256 and installed payload hash verification with the result. Offline upgrade/recovery checks use the published 0.2.39 ZIP, disposable prerequisites and representative preferences/saved places. PowerShell fixtures on Linux validate script transactions, not native Windows gameplay.

Owner checks: login and movement; F9 Server Families/Members/Rules/Settings/Links quiet Refresh; Commands tabs; I and M; U navigation clear with active tracking, vehicle selection/start/stop, player selection/find/stop and job denial; smart locking near each vehicle type and neither; stamina/oxygen notices; saved settings/locations; a complete restart and other-server round trip. Keep native Windows unverified unless separately reported. Final publication requires owner QA of the final stable archive as well.

On 2026-10-11 the owner reported “All tests positive” after testing the exact installed 0.3.0-rc.1 archive, SHA-256 `a8874a2dd31024ab2b57091cbe1b17eee2329db43c9c9f146aa030b3a0fadfb0`. The candidate checklist above is accepted on Linux/Wine; earlier feature-specific pending entries are historical snapshots. The owner subsequently reported “All final checks passed” for the exact final 0.3.0 ZIP, SHA-256 `1d572ee8db1d9f4fad4be58ca3201353a293fad7736f5d9aac50c7f66abbff78`, on 2026-10-11. Final login/movement, version label, F9/I/M/U, Server Refresh, lock notice, preferences/saved places and restart are accepted on Linux/Wine. Native Windows gameplay remains unverified.


## Local 0.3.1 vehicle discovery and lock visibility

Confirm 0.3.1 at login, normal movement and F9/I/M/U. In full and minimal dashboards, check that Locked and Unlocked labels agree with the larger closed/open icons, remain visible against dark and bright scenes, and fit above the health bar. Check cruise text, energy/notification stacking and submerged vehicle oxygen. An unavailable lock read must say Unknown.

Start `/luahzcapture vehicles` after login. Enter a personal vehicle, exit, then enter a family vehicle. Use the lock shortcut while seated to observe native lock changes. Run `/car engine`, `/car lights`, `/car window`, `/car hood` and `/car trunk` manually; use each twice when permitted to capture both states. Outside a vehicle with its trunk open, `/trunkbalance` captures the response. Use `/vstorage` and `/trackcar` menus manually for a vehicle you intend to spawn/track. Menu selection metadata omits input text and starts a bounded follow-up response window, with a 60-second selection deadline. Stop with `/luahzcapture off` before switching focus. Split into several short files if needed.

Capture never submits vehicle actions. Do not test selling, deleting, parking or purchases for this discovery step. Replies remain visible; captured windows can overlap unrelated traffic and do not prove vehicle ownership or response completeness. Check focus/disconnect cancellation and foreign-server inactivity. Local JSONL files stay private.


## Local 0.3.2 dashboard correction

The owner rejected the lock indicator’s separate square. Check that the indicator now shares the main dashboard background, with bright 44-unit icons and 15-unit state text fitting above the health bar. Full/minimal modes and notification/oxygen stacking should retain their accepted geometry. This is a Lua-only correction; resource bytes and capture focus/time limits are unchanged. The four 0.3.1 captures show both ownership types plus personal engine/lights replies; repeat only window/hood/trunk and storage/tracking flows, keeping the game focused until `/luahzcapture off`.


The next two owner captures ended normally on user stop and supplied personal window/hood/trunk replies, the storage list and cancellation, and a tracking list selection plus location/checkpoint reply. No further discovery capture is requested for this stage. On 2026-10-11 the closed-game full suite passed and four exact 0.3.2 Lua sources were installed with 715 protected files preserved; owner visual review of the no-square lock indicator remains pending. Storage spawn/store actions and family control behavior are still unverified.


On 2026-10-11 the owner replied “Looks good now” to the 0.3.2 Locked/Unlocked dashboard review. The shared-background presentation and readable state labels are accepted on Linux/Wine. This confirmation does not establish untested storage actions, family control behavior or native Windows gameplay.


## Local 0.4.0-rc.1 Vehicle menu

Confirm candidate version and normal login/movement/F9/I/M. K or `/luahzvehicle` opens the Vehicle UI on foot; My vehicles contains storage and tracking. U contains only Clear navigation and Find player. Escape, repeated hotkeys, typing, focus loss, death and disconnect must close/cancel appropriately without leaving controls locked. If K was already assigned, migration must preserve that binding and leave Vehicle menu unset; choose its shortcut in F9 normal keybinds.

Enter a personal vehicle and a family vehicle freshly (not merely reload while already inside). Confirm the dashboard and K ownership labels agree with the received entry message. Exit/change vehicles and check no stale ownership or control states carry over. Unknown ownership remains unspecified. Controls require the driver seat; engine/lights/window/hood/trunk are deliberate ordinary server toggles, and locks use the confirmed family order when available or the existing bounded fallback. The server may deny some commands on family vehicles. Labels begin unknown; only matching replies update a last-confirmed state, with no inferred success from the click itself. Roleplay/ordinary chat remain visible.

On foot, use Vehicle storage and deliberately select/cancel the native server menu. A spawned row may store the vehicle; no storage action is automated. Track a spawned vehicle, wait for one periodic refresh, then Stop tracking. Stored or Empty rows must not cause repeated requests. Confirm clear navigation under U still resets local finding/tracking only after the server acknowledgement.

Offline fixtures cover identity/epoch changes, early/late/conflicting ownership messages, wrong actors and reply parts, duplicate command echoes, state expiry, source-input cancellation, disabled controls, frame-stack cleanup, viewport fit, K collision migration, real runtime dispatch/input guards and GPS list/dialog ownership. Owner gameplay/visual QA remains pending.


## 0.4.0 final archive verification

The final player archive requires an owner report for its exact ZIP hash and source revision. Confirm login and movement, F9/I/M/U/K, preference persistence/restart, Trunk-on-foot and Controls-inside defaults, Alt cursor/movement behavior, personal/family dashboard badges and vehicle controls, silent menu Trunk balance versus visible manual `/trunkbalance`, storage/tracking, license refresh and an available profession action. Other-server isolation remains part of the check. Source/installer fixtures establish code and filesystem behavior; native Windows gameplay remains unverified. Exact archive hashes, deployment backup and owner results are recorded locally.
