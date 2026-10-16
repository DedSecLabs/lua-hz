# Assets, licenses and external files

## Public source boundary

The public source export includes original Lua/C/Python implementations, tests, current docs, license notices and the maintained Lucide UI SVG/PNG set. The Linux player download additionally uses `player-resources/` in this repository: the current HUD, Quickmap, portrait, native visual, and loading files. That directory is tracked for the automatic player release. The source-export tool still omits those binaries. The mimgui initialization adapter retains FYP's MIT notice. Lucide's ISC notice and applicable Feather MIT notice remain with those files. This is supported by the upstream [Lucide license](https://github.com/lucide-icons/lucide/blob/main/LICENSE) and [mimgui license](https://github.com/THE-FYP/mimgui/blob/master/LICENSE).

The source license does not grant rights to third-party visuals/software. The complete player inputs and existing player packages contain the visual groups below; source-only exports omit them. Earlier blanket statements that these binaries were excluded were inaccurate. The 2026-10-15 review reconciled Proper Radar maps, Zera weapon icons and Rubik notices with their original sources and applicable terms. DJDARKO font sheets, the separate HD radar/icon set, stock-skin previews and loading/other branding inputs still need provenance/public-use reconciliation before the next public package. See manifests/assets.json and THIRD_PARTY.md for the current scope. The project owner requested the existing README logo, but that request does not itself grant third-party rights.

## Resource inputs

| Resource group | Preparation/acquisition | Public package status |
|---|---|---|
| UI sidebar/close/status icons | Included maintained Lucide files and notices | Included |
| Rubik font | Unchanged Rubik Regular 2.300; matching upstream copyright/OFL metadata; full upstream OFL and authors included | Player input; OFL-1.1 notices reconciled |
| 36 Quickmap tiles | Proper Radar v1.3 author originals converted bilinearly to a 6x6 grid of 512x512 JPEGs | Player input; custom alternative-version terms and original/base credits retained |
| 46 weapon icons | Exact PNG matches to Zera's original HQ Weapon Icons archive; only filenames mapped to weapon IDs | Player input; custom mod-use grant with credit and original readmes |
| HD radar icons | Owner-supplied pack; hashes recorded by filename | Player input; provenance review pending |
| Custom HUD/dashboard font | Science Gothic original variable font rendered with tools/prepare_hud_fonts.py | Accepted atlas, original OFL/copyright/attribution and source hashes included |
| Cash/clock font | Exact legacy Pricedown Regular 3.200 (2004) and its original Larabie agreement, rendered with tools/prepare_hud_fonts.py | Accepted atlas, original agreement/copyright/kerning notice included |
| Restored native font TXD/widths and wanted star | Historical DJDARKO preparation; DooMknight is cancelled | Player input; provenance review pending |
| Historical custom HUD atlas | Retained hud-v0218/hud-font.png, no longer selected by current source | Excluded from new player archives |
| Standard skin previews | tools/prepare_portraits.py caches open.mp-linked images locally | Player input; provenance review pending |
| 144 native radar tiles / overview | Byte-identical Proper Radar v1.3 dictionaries; only map texture retained from the frontend dictionary | Player input; same Proper Radar terms/credits as Quickmap |
| Native icons | Separate owner-supplied preparation, not covered by the map attribution | Player input; provenance review pending |
| LuaHZ README logo | Existing selected imagegen menu logo, copied unchanged at the project owner’s request | Included at assets/branding/luahz-logo.png |
| Loading artwork / other branding | Selected imagegen outputs and saved prompts; user supplies input scenes/branding | Encoded loading input included; third-party inputs/marks review pending |
| GTA/client/runtime binaries and loaders | User's lawful compatible installation / upstream links in dependencies manifest | Not bundled |

Runtime visual assets are never fetched when opening a menu. Missing optional textures fall back or leave a diagnostic; do not call a sparse source-only installation visually equivalent to the approved QA build. Native installers fail closed without the verified originals/assets. A first-run dependency downloader is not implemented; development tools use explicit local inputs.

The accepted custom font groups are `hud-science-gothic-v042` and `hud-pricedown-v042`; both atlases reproduce the exact owner-tested PNGs. Source uses stable resource names, and final archive QA must check those packaged paths. `tools/prepare_hud_fonts.py` takes explicit font/license paths, verifies their original hashes and writes a new preparation directory without deploying. Full original notices also live under `docs/licenses/hud-fonts` for source exports. See [third-party notices](../THIRD_PARTY.md#custom-hud-fonts). The owner subsequently passed the consolidated Windows build with the stable resource paths on both classic SA-MP R5 and open.mp 1.7.0 (2026-10-16). Exact final archive QA is separate.

### Reconciled map/icon/font inputs — 0.4.2 preparation

The owner approved Proper Radar's Quickmap, ESC map and radar appearances in the Windows open.mp test copy. The maintained player input now contains the same 36 author-derived Quickmap JPEGs. All 144 native map tiles and the map-only overview were already byte-identical to the original Proper Radar v1.3 package and remain unchanged. Original/base credits come first; the variation is named **Proper Radar — LuaHZ Map Adaptation**. Source-project and classic-package English/Portuguese readmes accompany the resources.

Zera's original mod-use permission and rehosting restriction accompany the 46 unchanged weapon PNGs. The per-ID original filename mapping is in weaponicons/SOURCE.json. Rubik's font bytes are unchanged; complete upstream OFL.txt, AUTHORS.txt and attribution accompany it. Public provenance JSON uses source URLs and content hashes, not private machine paths. SOURCE.json records are retained in source; the packager excludes them from the game payload while including the human-readable notices through its existing resource-group traversal.

These input/notice changes do not modify a frozen published archive or imply every other group is cleared. A revised package needs its own committed inputs and exact-archive owner QA. No new startup code fix was needed: the original 0.4.2 code passed a fresh launch with custom artwork after the owner's peripheral disconnect/reconnect investigation; the initial delay's permanent cause remains unconfirmed.

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


## Documentation gallery — release 0.4.2

`docs/images/gallery-v042/` contains 34 exports from 31 owner-supplied 0.4.2 captures dated 2026-10-16. The owner explicitly selected Python crops and alpha masks. Every cropped RGB pixel is checked against its source; text, version labels and colors are retained exactly. Only review thumbnails are scaled. Translucent dashboard tint and the native player HUD backdrop remain captured; panel surroundings and padding are transparent. No generative editing or text retouching was used.

Settings and Character canvases are 1104×672; compact Quick Actions is 744×592; Vehicle menus are 433×410; dashboards are 472×256. `sources.json` records original/output hashes, crop boxes, masks, offsets, group sizes and capture notes without private machine paths. Full raw captures, including the duplicate Graphite view, are retained privately. The README and unpublished forum draft share tab order, including Families/Members/Rules/Settings/Links/Status and all six Character tabs. Older unmatched HUD-settings, map/radar, energy, Find player and trunk-balance illustrations are identified and preserved. One new server-help capture retains its incomplete-response warning; cropping does not imply that every option or request was tested.

## Documentation gallery — release 0.4.0

`docs/images/gallery-v04/` contains 17 owner-supplied screenshots captured in 0.4.0-rc.5. Native-resolution crops and alpha masks preserve every captured RGB pixel, including text and version labels. Game-blended outer panel edges are excluded; translucent dashboard tint and the native player HUD backdrop remain as captured. There is no raster scaling or text retouching. Matching transparent canvases use 13-pixel padding: F9/Character 1104×672, Vehicle menu 433×410, Quick Actions 744×648, dashboard 472×256, and player HUD 406×314. `sources.json` records source filenames/hashes, crop boxes, output hashes and group geometry. The older gallery and existing map/radar/energy/Find player captures remain intact.

## Vehicle storage icon — 0.4.2

The accepted Pinhead garage Storage icon is separate from the unchanged vehicle-v040 Trunk balance icon. player-resources/vehicle-v042 includes the owner-tested white-alpha PNG, original CC0 license, attribution and SOURCE.json with upstream URL/hashes. Packaging and local staging include the new versioned group; no existing texture is overwritten. Original geometry: https://github.com/waysidemapping/pinhead/blob/v15.25.0/icons/buildings/garage.svg.

## Accepted vehicle gallery update — 0.4.2

Seven further owner screenshots supply nine native-resolution exports: seven vehicle images are replaced and populated trunk contents/active tracking are added. Public gallery-v042 now contains 36 exports. Vehicle canvases now match the dashboard width at 472 pixels including transparent padding; menus are 472x410 and dashboards remain 472x256. Exact RGB preservation is checked before saving; older exports and all originals are archived privately. README/forum keep Controls, Trunk and My vehicles in UI order.
