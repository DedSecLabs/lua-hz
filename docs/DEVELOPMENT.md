# Development and reproduction

## Source-only checks

Use Python 3.11+, LuaJIT 2.1 and GCC on Linux. Create a virtual environment and install the pinned tooling requirement:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python tools/check.py --luajit /path/to/luajit
```

No GTA installation, downloaded prerequisites, art, network connection or account is required for these checks. Tests use explicit Lua stubs and temporary native/deployment fixtures. C policy tests use GCC AddressSanitizer/UBSan. They do not prove live graphics/network behavior. Optional `--moonloader /path/to/game/moonloader` verifies native/event/ImGui API names against the installed runtime.

## Native code build

The tested freestanding path uses host GCC plus MinGW x86 assembler/linker and libkernel32.a. On Ubuntu, developer packages are gcc, binutils-mingw-w64-i686 and mingw-w64-i686-dev; LuaJIT is a separate package. `--toolchain /usr` works with that standard layout. An extracted equivalent usr directory is also supported.

```sh
python3 tools/build_native_visuals.py --toolchain /usr
asset_fingerprint=$(python3 -c 'import json; print(json.load(open("manifests/dependencies.json"))["native_loading_artifact"]["resource_fnv32"])')
python3 tools/build_native_loading.py --toolchain /usr --asset-fnv "$asset_fingerprint"
```

The command above reads the matched artwork fingerprint from manifests/dependencies.json. A source-only loading build compiles code from that public fingerprint; deploying artwork still requires the paired external loading.enc. For a local artwork build, replace --asset-fnv with --asset /path/to/loading.enc. Native outputs stay under ignored build/native. The source contains all native implementation/build logic; upstream game addresses/layouts are references, not external compile-time source dependencies. The native helpers target only the fingerprints listed in the manifest.

## Local resources and deployment

Read docs/ASSETS.md. A source clone deliberately lacks third-party texture packs, stock-skin previews and loading artwork. Licensed Lucide UI files and the README/menu logo are included. Other resource groups are supplied from the owner's verified game installation or ignored .local/prepared-hud folders. Staging reports local provenance in build/manifest.json; a local QA ZIP is not a public release ZIP.

```sh
python3 tools/deploy.py stage --moonloader "/path/to/game/moonloader"
python3 tools/deploy.py install --moonloader "/path/to/game/moonloader"
```

`stage` prepares a local payload without installing it. `install` is for a first LuaHZ installation. For an existing deployment with its receipt, use `python3 tools/deploy.py update --moonloader "/path/to/game/moonloader"`; it replaces Lua sources and preserves installed resources. These Lua deployment commands do not install the early native loading helper or prepare missing external visual packs.

Install/update/restore preserve original backups and preferences. A live Lua-only update is possible with --live when textures are identical, followed by /luahzreload; native binaries and existing textures always require a fully closed game and SA-MP browser. Native visual preparation consumes verified local receipts and originals. native_loading_startup.py installs/updates the matched ASI/artwork pair with stock-binary guards and rollback. Never independently update one half of that pair. Native recovery commands are documented in docs/RECOVERY.md.

## Fresh-copy verification

```sh
python tools/export_source.py --output /path/to/source-export
python tools/verify_source_clone.py --luajit /path/to/luajit --toolchain /usr
```

The verifier exports only public source, makes a temporary local Git repository, clones it into a new directory, runs checks without --moonloader, then builds both native components from the public manifest fingerprint. It records a report in ignored build/. It never creates a GitHub repository, pushes, commits to the user's existing parent repository or accesses the game. This proves code/test/build portability, not redistribution permission or completeness of an external visual asset bundle.
