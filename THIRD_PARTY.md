# Third-party notices and provenance

The original LuaHZ Lua/C/Python implementation uses the root MIT license. It independently reconstructs visible LunaHZ behavior; compiled LunaHZ code is not included. This does not relicense third-party software/art.

## Included source/assets

src/lib/horizonbase/ui_backend.lua is an acknowledged adaptation of FYP’s mimgui 1.7.0 initialization adapter. Its original notice remains in source. Upstream: https://github.com/THE-FYP/mimgui (MIT).

The brief material-handler excerpt in docs/INSTALLATION.md describes the locally tested adjustment to FYP's MIT-licensed SAMP.Lua v2.0.4. Copyright (c) 2016, FYP @ BlastHack Team <blast.hk>. Upstream: https://github.com/THE-FYP/SAMP.Lua/releases/tag/v2.0.4. The following MIT terms also apply to that excerpt.

> Copyright (c) 2018 FYP <https://github.com/THE-FYP>
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

The maintained assets/ui-v0212 sidebar/close/status SVGs and rendered PNGs are Lucide icons. Their upstream source URLs and complete ISC plus applicable Feather MIT notices are in that folder. Upstream: https://github.com/lucide-icons/lucide. The existing generated LuaHZ menu logo is included unchanged at assets/branding/luahz-logo.png for the README at the project owner’s request. Source-only exports omit the separate player-resources binaries; the complete player edition includes those resource groups. Their individual provenance and review status follow below.

## External runtime and cosmetic inputs

The separate Linux/Wine base player preview bundles FYP's eight MIT-licensed SAMP.Lua v2.0.4 files with the documented material-handler adjustment. The packager verifies every file against the recorded tested hashes and includes the upstream full MIT license. Other prerequisite binaries remain separate downloads. This exception does not change the developer-preview packaging policy or permit inclusion of external visual packs.

MoonLoader, SAMPFUNCS, CLEO, the ASI loader, mimgui renderer, SAMP.Lua, GTA and SA-MP are separately installed prerequisites, not bundled. Exact locally verified fingerprints and upstream links are in manifests/dependencies.json. SAMP.Lua’s upstream is https://github.com/THE-FYP/SAMP.Lua (MIT); native/runtime redistribution is not assumed from a download link.

Historical acquisition records reference https://github.com/lunahz/dependencies. Matching bytes there do not establish that LunaHZ created the resources. Rubik, Zera weapon icons, Proper Radar maps and the accepted custom HUD fonts now have the original-source records and notices described below. Restored native font textures/proportions and the wanted-star image still derive from owner-supplied DJDARKO 2025 v1.0.1 inputs. Separate HD radar sprites and standard skin previews (linked by https://open.mp/docs/scripting/resources/skins) still need provenance/reuse reconciliation. These pending resources are present in player-resources and existing player packages; source-only exports omit their binaries. The unused legacy custom HUD atlas is retained as historical input but excluded from new player archives. Per-file hashes and review status are in manifests/assets.json and docs/ASSETS.md. Resolve the pending groups before the next public player package; attribution for a resolved group does not cover unrelated resources.

Loading/menu artwork uses server screenshots, the Horizon favicon/wordmark and GTA/SA-MP/software marks as references for original imagegen output. Prompts/provenance remain in private development records. The encoded loading artwork is present in the complete player inputs and existing packages; public-use review of the third-party inputs/marks remains separate. The README logo is the specific inclusion requested by the project owner. Native game packaging stays uncompressed.

Original-source comparison identified 61 current radar PNGs as pixel-identical to **-Quantum-**'s *Original Radar Icons in HQ / Radar Icons HQ Remastered* (2015), https://www.gtagarage.com/mods/show.php?id=26910. The per-file correspondence is recorded in manifests/assets.json. The original readme has no explicit reuse grant, so identifying the source does not clear redistribution or establish rights for the other icons. No game icons were replaced during this review.

## Rubik font

Copyright 2015 The Rubik Project Authors (https://github.com/googlefonts/rubik). The unchanged Rubik Regular font identifies version 2.300 and SIL Open Font License 1.1 in its metadata. Complete upstream OFL.txt and AUTHORS.txt accompany the font in player-resources/fonts/Rubik and the installed resource directory. Those notices are pinned to upstream revision e337a5f69a9bea30e58d05bd40184d79cc099628. Rubik retains its OFL license; the LuaHZ MIT license does not relicense it. See that directory's ATTRIBUTION.txt and SOURCE.json.

## Custom HUD fonts

**Science Gothic:** Copyright 2024 Font Detective LLC. Design by Thomas Phinney, Vassil Kateliev and Brandon Buerkle. Original source: https://github.com/googlefonts/science-gothic, revision `6e2b703b3df79fecf04cadc9c54ea68459856e50`. The custom HUD/dashboard atlas renders the unchanged variable font at weight 500, width 100, contrast 0 and slant 0. It retains SIL OFL 1.1 with no Reserved Font Name. Full copyright/license and attribution accompany `player-resources/hud-science-gothic-v042`; a source-export license copy is in `docs/licenses/hud-fonts`.

**Pricedown Regular 3.200 (2004):** Copyright 1998 Ray Larabie; the exact older font and its included Larabie Fonts software-product agreement came together from https://www.gta-sanandreas.com/downloads/gtafont.zip. This is the older licensed copy, not the current desktop-only download. The font file and alphanumeric designs were not edited. LuaHZ renders individual cash/clock glyphs; original pair kerning is not applied. The original name, agreement, copyright and this kerning notice accompany `player-resources/hud-pricedown-v042`, with the source-export agreement retained in `docs/licenses/hud-fonts`. The bitmap adaptation retains that agreement rather than LuaHZ's MIT license. Do not describe this font as OFL or public domain.

`tools/prepare_hud_fonts.py` checks exact font/license hashes and reproduces both atlases from explicit external inputs. The promoted atlas PNGs are byte-identical to those accepted in the owner's game. Numeric glyph geometry is included in source; original installable font files are not bundled. This custom HUD replacement does not establish reuse rights for the separate native GTA font textures or wanted-star image.

## Zera's HQ Weapon Icons

The 46 unchanged 256x256 weapon PNGs are from **Zera's HQ Weapon Icons for San Andreas**: https://www.gtagarage.com/mods/show.php?id=21062. Every included PNG matches an original author-archive file. LuaHZ maps their filenames to weapon IDs; the mapping and hashes are recorded in player-resources/weaponicons/SOURCE.json. Zera's custom readmes permit use in another mod with author credit and restrict standalone rehosting without permission. Original English/Portuguese readmes and ATTRIBUTION.txt accompany the icons. The artwork is credited to Zera and is not under LuaHZ's MIT license.

## Proper Radar — LuaHZ Map Adaptation

**Proper Radar v1.3: Junior_Djjr. Base: Grove Street Games (GTA Trilogy), Jéssica Natália. LuaHZ adaptation: LuaHZ contributors — Quickmap conversion and resource packaging.** Original release: https://www.mixmods.com.br/2022/07/proper-radar/.

The 36 Quickmap JPEGs are converted from the author's PC 512 tiles with bilinear resampling into a 3072x3072 combined map. The 144 native radar dictionaries and map-only overview retain the original Proper Radar content; unrelated frontend backgrounds are excluded. The source-project readme describes alternative-version publication with the original credits, Proper Radar name, variation name and latest version. Its original English/Portuguese text, classic-package readmes and attribution accompany player-resources/sa_map and the installed resources. Native map credits also appear in native-v0232/PROPER-RADAR-CREDITS.txt. These custom terms cover these map resources; they do not relicense other native font/icon resources or establish Horizon staff approval.

## Native API facts

Our native helpers are original implementations. Addresses/layout facts refer to plugin-sdk RenderWare.cpp, gta-reversed Font/Radar/TxdStore/LoadingScreen sources and imring/SAMP-API.lua v037r5/CNetGame.lua. No GTA or SAMPFUNCS binary/code is copied into a source export. The helper's Win32 imports are KERNEL32 only; game/plugin binaries stay stock on disk in the approved shared-server architecture.


## Dashboard closed-door icon

The dashboard-v031 closed-door icon is rendered from Pictogrammers Material Design `car-door-lock.svg`, using explicit white fill for runtime tinting. Upstream: https://github.com/Templarian/MaterialDesign/blob/master/svg/car-door-lock.svg. The icon is Apache 2.0; the upstream collection notice and full license accompany the resource group. Other copied dashboard PNGs retain their existing provenance.

## Vehicle interface icons

The vehicle-v040 resource group retains the exact eight locally tested PNGs. Streamline Ultimate's engine icon is CC BY 4.0, attributed to [Streamline](https://streamlinehq.com) / [Webalys](https://github.com/webalys-hq/streamline-vectors). MingCute's window, Pictogrammers Material Design's lights/users and Google's Material Symbols key/garage icons are Apache 2.0. Custom Brand Icons' hood/trunk icons are MIT. They were obtained through AllSVGIcons, converted to 128x128 white-alpha PNGs, and verified against normalized upstream geometry. Full licenses and per-file credit are included in player-resources/vehicle-v040/ATTRIBUTION.txt and its license files; source-only exports omit these PNGs. See its SOURCE.json for identities/hashes.

## Vehicle storage garage icon

The separate vehicle-v042 garage icon is Pinhead Map Icons garage by Quincy Morgan / Pinhead contributors, CC0-1.0. Original source: https://github.com/waysidemapping/pinhead/blob/v15.25.0/icons/buildings/garage.svg. Vector geometry is unchanged; white fill is rendered at 128x128 for theme tint. Attribution, original upstream license and source hashes accompany the resource group. The vehicle-v040 garage remains the Trunk balance icon.
