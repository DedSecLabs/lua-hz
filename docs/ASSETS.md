# Assets, licenses and external files

## Public source boundary

The public source export includes original Lua/C/Python implementations, tests, current docs, license notices and the maintained Lucide UI SVG/PNG set. The Linux player download additionally uses `player-resources/` in this repository: the current HUD, Quickmap, portrait, native visual, and loading files. That directory is tracked for the automatic player release. The source-export tool still omits those binaries. The mimgui initialization adapter retains FYP's MIT notice. Lucide's ISC notice and applicable Feather MIT notice remain with those files. This is supported by the upstream [Lucide license](https://github.com/lucide-icons/lucide/blob/main/LICENSE) and [mimgui license](https://github.com/THE-FYP/mimgui/blob/master/LICENSE).

The source license does not grant rights to third-party visuals/software. Public packaging review found no supplied blanket redistribution permission for the DJDARKO font sheets, user-provided HD radar set, reused LunaHZ map/weapon/font resources or stock-skin previews. Those binaries are excluded, with their sources/hashes described in manifests/assets.json. The loading illustration uses server screenshots and GTA/SA-MP/software/Horizon marks; loading artwork and other branding remain local pending a separate public-use decision. The project owner requested inclusion of the existing LuaHZ menu logo in the repository README; the unchanged PNG is included at assets/branding/luahz-logo.png. This request does not grant rights to third-party marks or other assets. The user's instruction authorizes this local development edit; it is not evidence of permission to publish every referenced mark/input.

## Resource inputs

| Resource group | Preparation/acquisition | Public package status |
|---|---|---|
| UI sidebar/close/status icons | Included maintained Lucide files and notices | Included |
| Rubik font, 36 Quickmap tiles, weapon icons | Verified existing resource/lunahz or resource/horizonbase installation; upstream lunahz/dependencies reference | External, review pending |
| HD radar icons | Owner-supplied pack; hashes recorded by filename | External, review pending |
| Bitmap HUD font / native font TXD | tools/prepare_hud_assets.py and native_fonts.py from separately acquired DJDARKO plain sheets/data | External, review pending |
| Standard skin previews | tools/prepare_portraits.py caches open.mp-linked images locally | External, review pending |
| Native icons / 144 radar tiles / overview | Verified local preparation/deployment receipts; native_visual_assets.py separates exact payloads | External, review pending |
| LuaHZ README logo | Existing selected imagegen menu logo, copied unchanged at the project owner’s request | Included at assets/branding/luahz-logo.png |
| Loading artwork / other branding | Local selected imagegen outputs and saved prompts; user supplies input scenes/branding | Local pending public-use decision |
| GTA/client/runtime binaries and loaders | User's lawful compatible installation / upstream links in dependencies manifest | Not bundled |

Runtime visual assets are never fetched when opening a menu. Missing optional textures fall back or leave a diagnostic; do not call a sparse source-only installation visually equivalent to the approved QA build. Native installers fail closed without the verified originals/assets. A first-run dependency downloader is not implemented; development tools use explicit local inputs.

## Work outside the source directory

Selected final art and its prompt are copied into ignored local branding/; original imagegen outputs also remain in the app's generated-images directory. Original user inputs live in their Downloads/Pictures folders or ignored local artwork-inputs. Generated resources, binary analysis and historical material live in .local/; staged payloads, native binaries and reports live in build/. The actual game folder receives controlled deployment changes and backups. Wine/Lutris configuration and prerequisite/toolchain installations live outside the project. These locations are described by local target/receipt files, never by hardcoded personal paths in public source.

Archive operations preserve old files with a moves.json ledger. New agents should not depend on those private archives for the current architecture/build workflow. SHA-256 manifests describe needed inputs; filenames/URLs and generation steps should be updated when replacing an asset set. Do not publish QA ZIPs: they contain locally reused assets and are intentionally distinct from the source export.

## F9 Server icon — local 0.2.45

The Server sidebar uses [Lucide server](https://lucide.dev/icons/server). Its upstream vector is `assets/ui-v0212/server.svg`; `server.png` is a 96×96 white-alpha runtime raster of the same rounded-rectangle/line geometry, matching existing F9 icons. The upstream URL is recorded in `assets/ui-v0212/sources.json`, and the existing Lucide/Feather notices remain in `LUCIDE-LICENSE.txt`. Staging copies the PNG into `moonloader/resource/horizonbase/ui-v0212/`; runtime tint supplies the selected orange or neutral gray. No generative image editing or unrelated texture replacement was used.

## Quick Actions icons — local 0.2.53

The Quick Actions menu uses the maintained Lucide map-pin-off, lock-keyhole, radar and search vectors in assets/ui-v0212, converted to 96×96 white-alpha PNGs with the bundled Sharp SVG renderer. Exact upstream source URLs remain in sources.json; the existing Lucide/Feather notices apply. These use the same icon family as F9.

The owner attributed the separate local Downloads/assets/luahz SVG folder to https://allsvgicons.com/. Its filenames/hashes and owner attribution are recorded privately in .local/asset-sources/allsvgicons-owner-folder.json. This aggregator-origin folder remains separate from the maintained Lucide menu catalog; no additional supplied files were added to the public payload by this build.

## Documentation gallery — October 2026

`docs/images/gallery-v03/` contains 25 owner-supplied screenshots captured in local build 0.2.54. The owner authorized native-resolution crops and transparency masks. Text, icons, colors and version badges retain their source RGB pixels; the game background outside each rounded panel is masked out. The narrow outer antialias already blended with the game is excluded rather than recolored. Translucent HUD interiors retain their captured scene tint.

Canvases share 13-pixel padding within each group: F9/Character 1104×672, Quick Actions 744×504, vehicle HUD 344×222, and stamina/oxygen 392×106. Exports are RGBA PNGs with no raster scaling. `sources.json` records source filenames/hashes, crop boxes and preparation details. These images show a development build; release documentation must identify that build or use new captures from the final release.

The previous gallery files remain intact. `minimap_776_canvas.png`, `quickmap.jpg` and `sa-mp-057.png` are deliberately unchanged. The new directory avoids changing images already embedded in the live forum post through its main-branch URLs.

The existing public forum header aliases (`luahz-hzheader.png` and its small variant) are now included in the source export's pinned branding list. Their bytes match the already committed public headers; other branding remains excluded.


## Dashboard lock visibility — local 0.3.1

The dashboard-v031 group preserves the previous run, swimming, unlocked-door and health icons byte-for-byte. The closed-door icon is re-rendered from the matching [Pictogrammers Material Design SVG](https://github.com/Templarian/MaterialDesign/blob/master/svg/car-door-lock.svg) with explicit white fill at 128×128, retaining its vector geometry and transparent background. The old black bitmap and dashboard-v0221 group are preserved. Runtime tint supplies the bright state colors; no raster painting or generative image edit is used. The upstream Pictogrammers license and full Apache 2.0 text accompany the new group. Local source bytes, render script and hashes are recorded under ignored .local/vehicle-capture-assets. New owner-supplied vehicle SVGs remain separate until the controls build selects them.


## Vehicle menu — local 0.4.0-rc.1

Eight owner-provided SVGs are rendered to 128×128 white-alpha PNGs under ignored .local/prepared-hud/vehicle-v040 for local QA: engine, lights, window, hood, trunk, key, users and garage. Source filename/hash and owner AllSVGIcons attribution are retained privately in .local/vehicle-capture-assets/vehicle-icon-provenance.json; originals stay untouched. Existing maintained Lucide close/radar and dashboard lock assets are reused. This group is not yet in public player-resources; verify each icon’s upstream collection/license before public packaging. Staging includes it locally; source exports omit it.

## Vehicle icon review — release 0.4.0

The eight existing vehicle-v040 PNGs are now staged in player-resources with per-file credit and full applicable terms. Exact normalized upstream RGBA matches were verified for all eight, retaining the owner-tested bytes: Streamline Ultimate engine (CC BY 4.0), MingCute window (Apache 2.0), Pictogrammers lights/users (Apache 2.0), Google Material Symbols key/garage (Apache 2.0), and Custom Brand Icons hood/trunk (MIT). Attribution/modifications are stated in ATTRIBUTION.txt; public SOURCE.json contains no machine paths/account data. Local preparation/verification logs stay ignored. This completes this group's previously pending review; source exports still exclude its raster inputs.


## Documentation gallery — release 0.4.0

`docs/images/gallery-v04/` contains 17 owner-supplied screenshots captured in 0.4.0-rc.5. Native-resolution crops and alpha masks preserve every captured RGB pixel, including text and version labels. Game-blended outer panel edges are excluded; translucent dashboard tint and the native player HUD backdrop remain as captured. There is no raster scaling or text retouching. Matching transparent canvases use 13-pixel padding: F9/Character 1104×672, Vehicle menu 433×410, Quick Actions 744×648, dashboard 472×256, and player HUD 406×314. `sources.json` records source filenames/hashes, crop boxes, output hashes and group geometry. The older gallery and existing map/radar/energy/Find player captures remain intact.
