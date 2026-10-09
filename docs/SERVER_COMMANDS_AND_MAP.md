# Server commands and map observations

2026-10-08 — LuaHZ 0.2.11

We do not have a complete Horizon server command catalog or access to its server source. LuaHZ currently integrates five server command families:

| Command | Current use | Evidence and limits |
| --- | --- | --- |
| /accept | Accept eligible repair, defense, sex, taxi and message-specified drug offers | Reconstructed from LunaHZ feature/configuration references and recognized normal offer messages; individual offer types still need live QA. |
| /find | Periodically request a selected player's location | Original tracking feature references and server response/cooldown handling; server job/permission rules still apply. |
| /cohort | Optional follow-up to a successful find response | Original tracking feature/configuration references; current response format still needs live QA. |
| /trackcar | Refresh a vehicle explicitly selected in the server dialog | Original vehicle-tracking feature references; dialog matching and cooldown handling have offline checks, current server behavior still needs live QA. |
| /reload 2 | Trigger the server's reload animation | Explicit user gameplay confirmation; the command itself did not produce reload audio. |

The user has also used /stats and /toys in custom bindings. /refshop and /refhelp appeared in server announcements. Those examples are not an exhaustive command catalog. LuaHZ commands such as /luahz, /autofind and /autotrackcar are local mod commands, not additional Horizon server commands.

The mod sends ordinary chat commands through the installed client and observes messages, dialogs, checkpoints and map icons through SAMP.Lua. It does not use a Horizon web API. SAMP.Lua exposes the normal SA-MP network events, rather than private server source or hidden world data. The standard map-icon message supplies a slot ID, coordinates, sprite type, RGBA color and display style. It contains no business name or explanatory text. [SA-MP-compatible map-icon interface](https://open.mp/docs/scripting/functions/SetPlayerMapIcon), [sprite IDs and names](https://open.mp/docs/scripting/resources/mapicons).

The yellow circles in the screenshot are LuaHZ's current placeholder rendering for received map icons. Their actual sprite types were retained in memory but were not written to the existing logs. Therefore the screenshot and those logs do not establish the meaning of each circle. Standard sprite names describe artwork, and Horizon may reuse them for different purposes.

To investigate, launch with 0.2.10 active before connecting, log in, and run /luahzdebug while the markers are present. The MoonLoader log will include a stable, sorted list with each marker's type, standard sprite name, RGBA value, style and coordinates. A type such as Hospital or Ammu-Nation identifies the selected symbol; a generic colored marker requires checking its location against the actual server location/help information. Reconnecting is necessary if the script was loaded only after the server sent its initial icons; missing markers must not be interpreted as evidence of no server icons.

This build replaces the plain player triangle with the user's original radar_centre.png, with heading rotation and a dark outline drawn at runtime. The 0.2.10 debug capture recorded 34 live icons spanning 19 standard sprite types. Version 0.2.11 now renders all these types using the corresponding HD pack artwork, with a complete mapping for sprite types 2–63. Types 0/1 use geometric markers; type 0 honors server RGBA and normal sprites keep intrinsic artwork colors. No Horizon-specific location labels have been guessed. Reloading the script during an existing connection loses its event-observation state; reconnect afterward to receive the server icons again.


## Streaming investigation, 2026-10-08

A later debug capture reports 52 current icons instead of the earlier 34. Its positions cover a different Los Santos area, and 33 of the previously used slot IDs now describe different type/position records. This supports the proximity-streaming interpretation, but the captures also cross a server restart, so they are not an isolated proof of exact stream-distance rules. Local observation must use position/type identity rather than permanently retaining server slot IDs.

The installed resource folders contain textures/fonts, without a full location database. Static inspection of the original LunaHZ map modules found event-driven icon management and sprite metadata, not an established complete Horizon location catalog. No complete verified catalog was found in the inspected local resources. Standard SA-MP supports 100 icon slots per player; dynamic server streaming is a common way to manage a larger world dataset. This does not establish which streamer implementation Horizon uses.

A complete initial-world map needs a verified location catalog supplied independently of the proximity stream (for example by the server or a vetted community dataset). Remembering observations can prevent losing previously discovered places across sessions, but does not reveal unseen locations. Persisted records should be curated as fixed points of interest rather than treating every observed marker as permanent/current: mission icons, ownership/availability symbols, player/vehicle tracking and checkpoint data may change. Current live markers should override matching remembered locations; remembered points should communicate that they are saved locations, not current status. Cross-server separation, slot reuse, removal ambiguity and duplicate suppression need implementation/QA before enabling persistence.

No persistent marker behavior was added during this investigation; 0.2.11 remains the active renderer. One debug after login and one after moving to a different neighborhood is sufficient for the next comparison. Exploring the entire map is not required for this test.


## Closed-session QA capture

The latest retained session log contains one post-login debug snapshot at 16:53:52 with 52 active icons, spanning 15 types. It ended with the normal LuaHZ unload and Session terminated messages at 17:00:04, with no reported component errors or exception/traceback entries. The user's native/Quickmap screenshots show the HD sprite renderer functioning in the Commerce area and the vehicle HUD visible. This is visual QA evidence, not confirmation of an exhaustive location catalog.

The 34-icon and 52-icon saved samples yield 70 distinct type/position observations when coordinates are rounded to 0.1 game units. The later inspection reread the same 52-icon snapshot; it did not add a new after-driving debug sample. Observation count is not a count of verified permanent businesses: duplicated nearby points, changing marker categories and server-specific uses remain possible. No additional full-map exploration is necessary for this rendering QA.


## Persistent Horizon locations, version 0.2.13

One Horizon catalog grows during normal play and survives stream-out, disconnect and restart. Remembered and currently supplied icons look identical. Near-identical positions merge independently of server slots; fresh observations replace types and coordinates. Generic/player/north symbols, waypoints and tracking checkpoints remain live only. The previous Horizon cache migrates automatically. Users can toggle remembering or reset the catalog. The local QA target starts with 69 observations from the user's own captures; these are not bundled in the release.

A reused slot or remove event cannot prove that a remembered place moved or disappeared: the same events occur when nearby markers stream out. A server restart also does not transmit an authoritative full catalog. Do not erase all remembered locations on either event. Removing genuinely obsolete locations requires a stable server place identity, explicit authoritative data, or a catalog reset.

No documented public Horizon world-data API was found in inspected public sources. The normal SA-MP event stream supplies map markers; the standard [query mechanism](https://open.mp/docs/tutorials/QueryMechanism) returns server information, advertised rules, basic player lists and latency. It does not expose character stats, commands, or a world location database.

A bounded read-only query on 2026-10-08 confirmed Horizon replies to information, rules and ping. It advertised gamemode HZ:RP v2.4.47(z), language English, a 500-player limit, and rules including weather, worldtime, weburl, lagcomp and protocol version 0.3.7-R2. Protocol version is not the locally installed client revision. Results are a transient observation, retained privately in .local/horizon-query-20261008.json. Query-based features are not yet added to the mod.

Useful candidates are a compact server status (online/max), latency diagnostics and the advertised gamemode version for update troubleshooting. Prefer existing in-client data where available rather than duplicate network polling. A changed gamemode version can suggest an update but cannot prove a map location changed.

/help describes supported player-facing commands. The mod can submit known read-only commands such as /stats and parse the chat/dialog/textdraw response, but these are ordinary visible game interactions, not hidden database queries. First capture actual categories, usage and response formats; then design requested fields and controlled refresh. Passive parsing of a user-requested /stats can establish reliable patterns before automatic requests. Scheduled commands must respect server cooldowns, avoid interfering with active dialogs and only suppress responses positively identified as belonging to a mod-issued request. No new command fetching or stats feature is implemented in 0.2.13.

## User-confirmed /help overview, 2026-10-08

Source: the user's /help screenshots from the 0.2.13 session. Parentheses denote the server's printed aliases/notes; they are not literal command arguments. These are observed command names, not established argument/response formats, permission guarantees or instructions to execute every command.

| Category | Commands shown |
| --- | --- |
| Help | /report, /reportdm, /newb or /newbie, /tognewbie |
| Account | /rules, /stats or /netstats, /inventory, /myguns, /buylevel, /upgrade, /changepass, /killcheckpoint, /resetupgrades (10k note) |
| Chat | /w or /whisper, /o or /ooc, /s or /shout, /l or /low, /b, /ad or /advertise, /f or /family, /me, /toggc, /togfam, /togcrew, /togwhisper, /tognews |
| Bank | /balance, /withdraw, /deposit, /wiretransfer, /abalance, /awithdraw, /adeposit, /awiretransfer, /tourhouse |
| General | /pay, /charity, /time, /buy, /id, /music, /showlicenses, /clothes, /buyclothes, /finddealership, /pbscore, /nearestbusiness |
| General continued | /shortcuts, /skill, /stopani, /do, /me, /kill, /droplicense, /calculate, /car, /families, /gethelp, /members, /chatanim |
| General continued | /cancel, /accept, /eject, /usepot, /usecrack, /contract, /service, /checkweed, /findcartuning, /settings, /info, /chud |
| Other help categories | /cellphonehelp, /carhelp, /househelp, /toyhelp, /renthelp, /jobhelp, /leaderhelp, /animhelp, /fishhelp, /insurehelp, /businesshelp, /bankhelp |

Likely data candidates include /stats (character data), /balance (bank balance), /inventory and /myguns. The location-related commands and /carhelp, /businesshelp, /househelp, /jobhelp may reveal supported location requests. Each format must be captured before implementing an adapter. Location commands may create checkpoints or dialogs, so they must not be issued indiscriminately in the background. Account, payment, transfer, skill and destructive commands are not data-fetch candidates merely because they appear in /help.

The same session debug recorded 96 remembered locations and 34 currently received icons. Normal gameplay continued growing the disk catalog. Its log ended with a normal unload/session termination and no component errors. It did not record turf state, so the exact live flash colors/count from that session cannot be recovered retrospectively. Version 0.2.14 adds those diagnostics, corrects ABGR decoding, backfills the current client gang-zone pool and makes Quickmap leave movement/driving/cruise active.

## Commands-page distinction and latest QA, version 0.2.15

The Commands page is a guide to LuaHZ's own registered chat shortcuts. /autofind and /autotrackcar orchestrate normal server commands; auto-accept toggles and HUD shortcuts change local preferences. /luahzdebug and /luahzreload are LuaHZ troubleshooting commands. They are not an exhaustive Horizon /help list. This matches the feature-oriented role of the reconstructed LunaHZ Commands reference; no claim is made about the original author's undocumented design intentions.

The 0.2.15 page names that scope, groups local commands by purpose, documents the existing reload entry and directs users to Horizon's /help. It does not issue commands or intercept Horizon /help. The original user-supplied help overview remains the source for server-command discovery.

The latest 0.2.14 session's two captures reported active=0 and flashing=0 gang zones without scan errors. Both preserved the 106-location catalog, and the session ended normally. This is consistent with no displayed SA-MP turf zones at capture time. It does not prove how an active flash renders; that check remains pending.


## Character status fetching — 0.2.16

/luahzstatus and I open a local UI. /stats is the ordinary Horizon server command used for its snapshot. One automatic request follows the welcome, and Refresh sends an explicit request with a ten-second gap. No repeating polling or UDP query is involved. Incoming chat/dialog text is parsed only within a bounded requested response and after an own-character name/Level header. The schema comes from the user's previously supplied /stats screenshot, with live server QA still required. Manual /stats remains visible and also updates the panel. No fields persist to disk; the debug command includes only bounded recognized stats rows. Unknown/missing fields remain unknown.

HUD design references viewed: https://imgur.com/UGft54Q, https://user-images.githubusercontent.com/21023513/217389952-d6ff4e65-5f72-42f5-95c0-1d4f28c3db3d.png, https://www.gtainside.com/img/202504/b/1745084317_1745066291_2.jpg. These demonstrate layout/art direction, not redistribution licenses. Obtain original source/license information for any new HD icons or numeric font.


0.2.17 presentation: requests owned by LuaHZ (login/Refresh) silently capture only matched stats chat rows and their exact observed framing. Manual /stats stays visible, including a manual request taking over one already pending. Normal/foreign/unknown messages and dialogs pass through. The 0.2.16 debug captured all 38 schema fields successfully.
