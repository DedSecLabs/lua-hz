# Releases and player downloads

The latest published player download is [LuaHZ 0.4.0 — My Car! My F\*\*\*in’ Car!!](https://github.com/DedSecLabs/luahz/releases/tag/v0.4.0), published on 2026-10-12. The owner passed that exact final archive checklist on Linux/Wine. The exact 0.4.1-rc.1 player checklist has also passed on Windows 11 with both open.mp and classic SA-MP R5; the foreign-server black splash reproduces independently of LuaHZ. Historical player releases and checksums are preserved.

The next patch is **0.4.1 — Launcher Choice**. Its Windows checklist/final smoke and Linux CI checks passed. A strict GCC formatting-only correction and publication documentation update preserve all 694 tested game files; the repackaged source metadata still needs owner acceptance under the exact-archive rule below. Preparation does not change the latest stable download.

## Player candidate workflow

Use `release/<core-version>` for each release, starting before preparation or the first push. Follow [development style](DEVELOPMENT_STYLE.md) for branches, commits, PRs, tags, themes and asset filenames. Check the complete naming set together before pushing.

`tools/package_player.py` builds `LuaHZ-<version>-player.zip` from a clean checked Git revision, maintained source/UI assets and the explicit `player-resources/` directory. Prerequisite software stays separate. The archive includes install and restore scripts for Linux/Wine and PowerShell, installation instructions, release notes and a complete payload hash list. Preferences, saved places, account data and logs are never packaged.

`.github/workflows/player-release.yml` verifies source/recovery checks and package checksums, then saves an Actions artifact. On main it prepares a **draft prerelease**, never an automatic public release. A published tag is left unchanged. A draft can be refreshed, which invalidates earlier QA for its replaced bytes; test the exact final archive before publication. Branch runs build artifacts without creating a release.

New player tags use `v<version>`, such as `v0.3.0-rc.1` and `v0.3.0`. The archive retains the `-player.zip` edition suffix. Historical tags such as `v0.2.39-player` remain unchanged. Changes are compared with the previous stable player tag, excluding RC, base and source-preview tags.

1. Freeze the feature batch, record pending QA, and synchronize the version in `manifests/release.json`, `src/HorizonBase.lua`, `tools/deploy.py`, the runtime notice and F9 version label. Keep the historical F9 changelog. Choose the release theme in `manifests/release.json` as `release_name`; the player manifest and draft workflow carry that name forward. Prepare the new README on the release branch with its planned tag URLs so the tagged source snapshot includes it; activate it on the default branch after publication and live-link verification.
2. Write player-facing changes in `docs/releases/<major.minor.patch>.md`. RCs and the final milestone share that change interval; verify claims against the shipped code and the previous public release.
3. Run `tools/check.py`, source export and fresh-clone verification. Validate shell and PowerShell installer upgrades/recovery, and check the generated release notes and ZIP contents. Native Windows gameplay QA remains a separate report even when PowerShell fixtures pass on Linux.
4. Commit the actual release inputs before packaging. The packager rejects a dirty working tree or a revision other than HEAD; its recorded revision must represent the payload.
5. Build to a new directory and verify `SHA256SUMS.txt`. Test upgrade from the previously published archive, preserving settings, saved locations, unrelated mods and rollback.
6. Install the exact candidate with the game/browser closed. The owner launches it and confirms changed behavior. Keep the archive hash and deployment receipt with that result.
7. After owner QA, prepare the final version as a new archive/commit. Even a version-only rebuild is a different archive: install it and obtain the owner's final smoke-test result before publishing. Changed public bytes always require a new version.
8. Publish intentionally. Review the four attachments, final notes and tag revision. Update the README and give the owner forum section replacements only after the release/image URLs exist. The owner edits the forum post.

## Local packaging

```sh
python3 tools/package_player.py --output dist/player-030-rc1 \
  --revision "$(git rev-parse HEAD)" \
  --resources player-resources --asi player-resources/LuaHZLoading.asi
cd dist/player-030-rc1
sha256sum --check SHA256SUMS.txt
```

Never use the installed game, private resource experiments or a local QA ZIP as a public packaging input. Do not overwrite an earlier output directory. Retain the previous published archives, tags and checksums.

## Upgrade and recovery

First installation uses `install.sh <game>` or `install.ps1 <game>`. Existing LuaHZ installations require explicit `--upgrade` or `-Upgrade`. Both paths verify prerequisite/payload hashes before writing, reject unowned or linked destinations, back up overwritten files, verify the installed payload and roll back failed writes. Files under `moonloader/config` are not payload targets.

The installer prints a recovery command for its new `LuaHZ-backups` directory. Recovery refuses files modified after installation. Obsolete resource groups are left untouched; recovery restores the previous overwritten payload and removes newly added files. Native helpers/resources require GTA and the SA-MP browser to be closed. Install the separately required SilentPatchSA 1.1 Build 34.1 before upgrading from 0.2.39.

## Required player release presentation

The GitHub title is `LuaHZ <version> — <feature name>`. Choose a theme that describes the release during preparation. Do not repeat it as a heading in the release body. The generated body, attached `RELEASE_NOTES.md` and notes inside the ZIP use this order:

1. **Mod Changes**: what players will notice since the previous published player release. Include intervening local versions; use the F9 changelog as the baseline, not commit subjects. If no behavior changed, say so.
2. **What's Changed**: source commit subjects in the exact previous-stable-tag-to-packaged-revision interval, followed by the **Full Changelog** compare link.
3. **Installation**: contents, separately installed prerequisites, game-folder definition, first installation, upgrade/recovery and useful controls. State the actual platform QA limits.
4. Footer: linked **Source commit** and actual payload **Files** count, both derived from the package.

Immediately before the footer, include:

> Download `LuaHZ-<version>-player.zip` to install the mod. The “Source code” archives are for developers.

Upload exactly these four release assets:

- `LuaHZ-<version>-player.zip`
- `release-manifest.json` with the source revision and complete payload hashes
- `RELEASE_NOTES.md`
- `SHA256SUMS.txt`

Verify section order, absence of a repeated release title, change interval, agreement with F9, installation steps, revision/file count and all four assets before publication.

## Earlier preview editions

The published 0.2.35 base preview remains unchanged. Its separate workflow now creates drafts for new versions. `tools/package_base.py` excludes native graphics helpers and full visual assets; it is not the complete player edition. Its Linux/Wine clean-install owner test is recorded in STATUS.md.

`tools/package_release.py` and `release.yml` create source/developer previews with audited source and compiled x86 native helpers. They exclude the external texture/font/portrait/loading packs and prerequisites, so they cannot reproduce the approved player visuals. The developer packager deliberately refuses its own full-player mode; `package_player.py` is the separate complete archive path. See [development](DEVELOPMENT.md) and [assets](ASSETS.md).
