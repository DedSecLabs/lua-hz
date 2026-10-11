# Horizon feature roadmap

2026-10-11. Current local build is 0.2.54, installed for owner Quick Actions alignment QA. The owner accepted the 0.2.52 notification/energy-panel presentation. The owner reported 0.2.50 tests positive. The owner confirmed the 0.2.49 menu and smart locks work. The owner reported stable gameplay after the SilentPatch streaming fix, tested the information pages, and reported “looking good” after the latest quiet-refresh/presentation update. Observation and capture infrastructure is implemented; the Server information pages are implemented. Two-command lock bindings are implemented for owner QA; Quick Actions is implemented for owner QA; the compatibility restriction policy remains unfinished. No new player release has been published.

## Current progress against the original ten points

| Point | Current status | Remaining work |
| --- | --- | --- |
| 1. `/buylevel` | Character Status can display remaining respect from an exact manual reply; never automatically requests a purchase. | Broader response variants and live level-change QA. |
| 2. Combined vehicle locks | Smart personal/group fallback implemented and owner-reported working in 0.2.49; 0.2.50 replaces owned no-nearby chat errors with one notice. The keybind editor separates Normal keybinds and Command combos. | Test smart success/failure/timeout behavior, lock/unlock formats, repeated presses and cancellation. |
| 3. `/rules` | Server → Rules displays the captured summary and copies the server-referenced website. | A verified direct full-rulebook destination would improve the current website link. |
| 4. `/families` | Searchable table implemented; all 12 rows reach the client, including the first two. | Broader long-name/layout and changed-roster QA. |
| 5. `/myguns` | Parked at the owner’s request. Existing capture findings are retained. | No further investigation or feature work until the owner resumes it. |
| 6. `/settings` | Read-only server settings display implemented. | Optional controls require verified command mapping and response handling. |
| 7. `/killcheckpoint` | Four-action U panel implemented in 0.2.53, with exact confirmed local navigation cleanup. | Owner-test clear/lock/tracking/find flows, panel input guards and interruption cases. |
| 8. `/members` | Searchable roster with names, titles and family ranks implemented; quiet-refresh timing addressed in 0.2.47. | Broader empty-roster/formatting/manual-command QA. |
| 9. `/info` | Website/forums/Discord/faction/gang links implemented with Copy URL. | Direct link opening is optional future work. |
| 10. Server version changes | Event observation, session cleanup and observed/reference status implemented. | Changed/unknown-version notice, selective basic mode and explicit session override. |

Next implementation stage: owner-test the 0.2.54 Quick Actions presentation and remaining action flows; then address the server-version compatibility policy. Compatibility policy and any server-setting controls follow their own verification. The original build plans below retain the intended behavior and QA requirements; their evidence lists describe the initial plan, while this table records current progress.

## Build 1: observations and compatibility status

Add opt-in, bounded response capture for the commands discussed below, preserving normal chat and dialogs. Local 0.2.43 can explicitly request the six read-only commands through `/luahzcapture <name>` with recording armed before sending; manual observation mode remains for intended owner-issued actions. Observe incoming chat, dialogs, textdraws and relevant checkpoint/map-icon events while the owner manually exercises the commands. Keep captures in ignored local files; public fixtures must omit personal account details. Never issue `/buylevel` to obtain data: it can purchase a level.

Attempt to observe the login gamemode version, currently shown as `2.4.47 [Z]`, through incoming textdraw events/updates. Do not scan native textdraw strings. Cover fresh login, script reload, reconnect and gamemode restart; reload without fresh events may leave the version unknown. Clear session observations appropriately; missing data means unknown. Do not authorize Horizon activation from version/banner text: the exact endpoint gate remains authoritative.

Display observed version and verified compatibility status in F9. Do not equate an observed version with full verification of all features. `SERVER_COMMANDS_AND_MAP.md` records an earlier read-only query advertising `HZ:RP v2.4.47(z)`; normalize known display variants only after establishing their meaning. Prefer client observations over adding network polling.

First verify observation reliability. Then implement the discussed UX: one notice per session for changed/unknown versions, a default basic mode, and an explicit session choice to enable server helpers. Define basic mode by actual dependencies: pause server parsing/actions/layout changes that have not been verified, restore owned server display changes, and retain independently validated local features. Version detection needs a minimal observer; it cannot prevent the game from joining. Session overrides must never bypass native binary or endpoint guards. Server versions and LuaHZ versions are independent; a server update alone does not require a matching LuaHZ release.

Owner check: capture the missing lock responses and full command output; confirm version observation and ordinary chat/dialog behavior. Offline checks should cover response boundaries, incomplete data, reconnect cleanup and version display variants.

## Build 2: information pages (local 0.2.44, QA pending)

Use one Horizon page in F9 with subpages rather than adding a sidebar tab for every command. Use Character Status for account-specific data. Display refresh time and incomplete/stale status; keep manual command responses visible. Add explicit refresh for verified read-only requests without continuous polling.

| Original point | Planned behavior | Evidence still needed |
| --- | --- | --- |
| 1. `/buylevel` | Character Status shows remaining respect reported by a manually issued command, next to existing `/stats` respect. Do not invent a level formula or total threshold. | Response variants, expiry after changes to level/respect. |
| 3. `/rules` | Scrollable current server summary plus a verified full-rulebook link. | Complete response boundaries and authoritative rulebook URL. |
| 4. `/families` | Searchable table with family, leader, total members and online count. | Confirm rows 1 and 2 reach the client; the screenshot starts at row 3 with ten visible rows. Do not label a partial capture complete. |
| 6. `/settings` | Display confirmed server toggles separately from LuaHZ preferences. | Full response, wrapping and exact command-to-setting mapping. |
| 8. `/members` | Family/group roster displaying member names, ranks and the other server labels. Parenthesized numbers are family/group ranks, as confirmed by the owner. | Response boundaries, empty roster, formatting variants. |
| 9. `/info` | Community links: website, forums, Discord, Faction Discord and Gang Discord. | Full captured targets and link-opening behavior in the supported environment. |

Owner check: compare every displayed row/field to its normal server response, including long lists and refreshing after state changes.

## Build 3: shortcuts and actions

Point 2: extend custom keybinds to explicit command steps. One vehicle-lock binding sends `/pvl` (alias of `/pvlock`, personal vehicles) and `/gvl` (group vehicles), with a controlled gap. These distinct scopes are owner-confirmed. Execute once per press, prevent overlapping sequences, preserve existing single-command bindings, and cancel unsent steps on loss of authorization or relevant input/session eligibility. Verify actual success, failure and cooldown responses before choosing the gap. Do not manufacture a smart ownership detector from the native lock state.

Point 7: add a compact Quick Actions panel with text and an icon, opened by a configurable hotkey. U is the proposed default, subject to conflict checks. Its Clear action sends `/killcheckpoint` once and explains that the server also resets trackers and accepted fares. On recognized confirmation, coordinate local autofind/vehicle-tracking cancellation and transient checkpoint cleanup so queued requests do not recreate a marker. Preserve saved POIs and unrelated state; a rejected/timed-out action is not a confirmed clear.

Point 6 follow-up: add server-setting controls only after the read-only display and command mapping are verified. Refresh after a toggle rather than assuming an old snapshot proves the resulting server state.

Owner check: personal-only, group-only and nearby mixed vehicles; held/repeated presses; typing, dialogs and disconnect during a sequence. Check checkpoint clear with local tracking active, response failure, hotkey conflicts and server settings changed outside LuaHZ.

## Parked: `/myguns` (point 5)

The supplied screenshot contains `1791719036`, which converts to 2026-10-11 11:43:56 UTC and is consistent with the displayed 13:43:56 at UTC+2. It is a timestamp. The meaning of the separate signed number `-1248672477` is unknown; the screenshot does not establish an X/Y/Z position.

Do not investigate further until the owner resumes this point. If resumed and the server provides usable positions, consider explicitly requested gun markers in Quickmap, with clear transient ownership and cleanup. If it supplies only inventory/history, design that view instead. Do not decode an undocumented number into an invented location or promise a map feature before the evidence exists.

## Quick Actions scope (four controls approved and implemented locally)

The owner wants a useful player panel beyond a single checkpoint-clear action. The approved first build contains Clear navigation (server checkpoint/trackers/fares plus confirmed local cleanup), smart nearby-vehicle lock, vehicle tracking with the existing selection flow, and Find player with a name/ID selector and visible detective-job requirement. Stop animation (/stopani) is a simple candidate whose live behavior should be verified. Expose running tracking state and explicit Stop controls; actions remain user-triggered and send once.

Later candidates include My vehicles (/car), service requests (/service), and destination helpers (/nearestbusiness, /finddealership, /findcartuning). Their argument/dialog/response behavior needs capture before designing controls. Server preference switches can use the existing /settings snapshot after toggle mappings and confirmations are verified. Payment/transfer actions are better presented in Character Status → Finances with recipient/amount review. Avoid padding the panel by duplicating existing information pages; keep details in F9/I and make U useful during play. These are discussion proposals rather than implementation promises.

## Completion and publication

Implement one local build at a time, run relevant source checks, deploy to the existing QA target with backups, and let the owner test that exact build. Record accepted behavior and remaining limitations in STATUS/QA. Keep 0.2.40's accepted oxygen fix in subsequent builds. Publication remains a separate step and must follow RELEASING.md, including player-facing Mod Changes and the agreed release body/asset presentation.
