# Releases and player downloads

Players will download a named player ZIP from [GitHub Releases](https://github.com/DedSecLabs/lua-hz/releases), install the separately linked prerequisites, and follow the package's installation guide. They will not need to clone the repository or compile code. GitHub's automatic **Source code (zip)** and **Source code (tar.gz)** downloads remain developer source.

## Available packaging today

The separate **Base player prerelease** workflow builds LuaHZ-0.2.35-base.zip and publishes a new testing prerelease after source/installer checks. It includes the Lua feature modules, maintained UI icons/logo and verified MIT SAMP.Lua files, with a Linux/Wine shell installer and guarded recovery. It excludes native graphics helpers, HD assets, portrait previews and Quickmap backgrounds. The owner passed a Linux/Wine clean-install test of the published 0.2.35 base ZIP on 2026-10-09. That test is recorded in STATUS.md. The Linux player release workflow packages `player-resources/` into `LuaHZ-<version>-player.zip` and publishes tag `v<version>-player`. Windows uses the same archive by copying `moonloader` and `LuaHZLoading.asi` into the GTA folder. A later run replaces that tag's ZIP, checksums, and notes so the file inside the download matches the release page. See [base installation](BASE_INSTALL.md) for the earlier small preview. The base preview is left unchanged on reruns. Prerequisite binaries remain separate.

This minimal edition is built by tools/package_base.py. The developer-preview packager's full-visual player mode remains disabled; its policy below is separate from the base edition.

The **Draft release** workflow builds a **developer preview**, not the complete player mod. It contains audited source, licensed UI assets, the logo and our compiled x86 native helpers. External texture/font/portrait/loading resources and prerequisites are absent. `START-HERE.md` inside the ZIP explains these limits and points contributors to the development guide. The helpers cannot reproduce the approved visual build without their matching external resources.

The download is named `LuaHZ-0.2.35-developer-preview.zip`. `release-manifest.json` records the source commit and every payload hash; `SHA256SUMS.txt` covers the ZIP, manifest and release notes.

## Automated draft workflow

1. Open **Actions → Draft release → Run workflow**, choose **main**, and run it. A change to the packaging tool, release policy or workflow on main also runs it automatically.
2. Actions checks the Lua/Python/C source, builds both native helpers, exports eligible source and assembles the preview.
3. Actions verifies checksums, saves a 30-day build artifact, then creates or updates a **draft prerelease** with tag `v0.2.35-source-preview` at the exact tested commit.
4. Review its notes and four attached assets (ZIP, checksums, manifest and notes file) on the Releases page while signed in. A draft is visible to repository members with the necessary access; players see it only after publication.

Pull requests build and verify artifacts with read-only repository permissions. They cannot create releases. Only the separate main-branch draft job receives write permission. The workflow never publishes a release automatically. If the version is already published, it reports that the release is unchanged and finishes successfully; verified build artifacts remain available on the run. Use a new version for another release. A rerun can replace the assets of an existing draft; earlier build artifacts remain available during their retention period.

The version in `manifests/release.json` must match `src/HorizonBase.lua` and `tools/deploy.py`. Bump those together for a new mod version. Native loading builds always use the paired resource fingerprint in `manifests/dependencies.json`.

## Local packaging

First run the checks and both native build commands in [development](DEVELOPMENT.md), then:

```sh
python3 tools/package_release.py --output dist/release \
  --native-dir build/native --revision "$(git rev-parse HEAD)"
cd dist/release
sha256sum --check SHA256SUMS.txt
```

Use a new output directory for another local build; existing output is preserved. The packager uses the audited source exporter plus the two explicitly named original native builds. It never imports the installed game, private `.local` resources, branding experiments or `LuaHZ-local-QA.zip`.

## Player release

`LuaHZ-0.2.35-player.zip` is the published player download. `tools/package_player.py` builds it from `player-resources/`, and `.github/workflows/player-release.yml` publishes tag `v0.2.35-player`. When that tag already exists, the workflow replaces the ZIP so `INSTALL.md` inside it stays current. The developer-preview packager still refuses its own player mode; that switch does not affect this download. A Windows play report is the remaining check. Prerequisites remain separate. GitHub Packages is unused because these downloads are ZIP release assets.

GitHub references: [releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases), [draft/prerelease CLI](https://cli.github.com/manual/gh_release_create), [workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts).
