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

The maintained assets/ui-v0212 sidebar/close/status SVGs and rendered PNGs are Lucide icons. Their upstream source URLs and complete ISC plus applicable Feather MIT notices are in that folder. Upstream: https://github.com/lucide-icons/lucide. The existing generated LuaHZ menu logo is included unchanged at assets/branding/luahz-logo.png for the README at the project owner’s request. All other HD radar/branding/font/map/portrait textures remain excluded and retained locally.

## External runtime and cosmetic inputs

MoonLoader, SAMPFUNCS, CLEO, the ASI loader, mimgui renderer, SAMP.Lua, GTA and SA-MP are separately installed prerequisites, not bundled. Exact locally verified fingerprints and upstream links are in manifests/dependencies.json. SAMP.Lua’s upstream is https://github.com/THE-FYP/SAMP.Lua (MIT); native/runtime redistribution is not assumed from a download link.

Reused LunaHZ resources reference https://github.com/lunahz/dependencies. Native/HUD font preparation uses owner-supplied DJDARKO 2025 v1.0.1 plain sheets/data. HD radar sprites come from the owner-supplied pack; Proper Radar v1.3 has Junior_Djjr/Grove Street Games/Jéssica Natália provenance. Standard skin previews are linked by https://open.mp/docs/scripting/resources/skins. Their binaries remain external and public package permissions need review. Per-file hashes and grouping are in manifests/assets.json; acquisition/preparation roles are in docs/ASSETS.md.

Loading/menu artwork uses server screenshots, the Horizon favicon/wordmark and GTA/SA-MP/software marks as references for original imagegen output. Loading artwork and other branding are retained for authorized local QA with exact prompts/provenance, and excluded from public source pending a separate public-use decision. The README logo is the specific inclusion requested by the project owner. The latest edit changes only the upper-left scene; native game packaging stays uncompressed.

## Native API facts

Our native helpers are original implementations. Addresses/layout facts refer to plugin-sdk RenderWare.cpp, gta-reversed Font/Radar/TxdStore/LoadingScreen sources and imring/SAMP-API.lua v037r5/CNetGame.lua. No GTA or SAMPFUNCS binary/code is copied into a source export. The helper's Win32 imports are KERNEL32 only; game/plugin binaries stay stock on disk in the approved shared-server architecture.
