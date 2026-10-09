# Server isolation

The user approved 0.2.33 after HZ → another server → HZ tests using the same launcher/installation. Native fonts/icons/maps and the loading screen/bar were explicitly confirmed after repeated tests. The normal-launch workflow is accepted on Wine; distinct same-process reconnect/native Windows coverage is not implied.

The Lua bootstrap verifies native peer 213.32.6.232 and numeric port 7777, including availability/state guards. Names, welcome text and dialogs cannot activate it. None/disconnected contexts stop features. Settings/UI/native helper/event/command resources load lazily only on HZ. Callback/frame/input/command checks prevent stale handlers from affecting another endpoint. Cleanup releases controls/HUD/blips/queued traffic and resets login data.

The native visual DLL validates the game/client and native peer independently. It transfers/retains owned sprite/raster references and font widths, with restoration and stream-out protection. The early ASI only parses an unambiguous approved startup IP/hostname and port; other/unknown launches create no worker, read no artwork and patch nothing. HZ startup redirects the verified native resource/render/bar operations in memory, preserving stock files on disk. Native peer monitoring disables custom rendering when context is lost.

The unavoidable tiny bootstrap/startup selectors execute to decide whether features may load. Feature modules loaded in a previous HZ session can remain cached but inactive; fresh other-server launches do not load them. This project does not prevent independently installed prerequisite/other mods from loading. Unknown native builds/invalid assets fail closed to original behavior.

Policy, bootstrap, runtime transition, stale-owner, renderer-lock, asset validation and rollback tests cover the offline boundary. In-game tests remain the user’s responsibility. The new 0.2.34 tile preserves this architecture; only its visual QA is newly pending. See ARCHITECTURE.md, STATUS.md and QA.md.
