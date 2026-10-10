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
