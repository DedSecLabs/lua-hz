# Releases and player downloads

Players will download a named player ZIP from [GitHub Releases](https://github.com/DedSecLabs/lua-hz/releases), install the separately linked prerequisites, and follow the package's installation guide. They will not need to clone the repository or compile code. GitHub's automatic **Source code (zip)** and **Source code (tar.gz)** downloads remain developer source.

## Available packaging today

The separate **Base player prerelease** workflow builds LuaHZ-0.2.35-base.zip and publishes a new testing prerelease after source/installer checks. It includes the Lua feature modules, maintained UI icons/logo and verified MIT SAMP.Lua files, with a Linux/Wine shell installer and guarded recovery. It excludes native graphics helpers, HD assets, portrait previews and Quickmap backgrounds. No clean-install gameplay or Windows support is claimed before the corresponding live tests. See [base installation](BASE_INSTALL.md). Published versions are left unchanged on reruns; prerequisite binaries remain separate.

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

## Preparing the complete player release

The tracked policy in [release.json](../manifests/release.json) lists the current blockers. Before introducing a `LuaHZ-<version>-player.zip`:

- Acquire permission for the required visual resources or replace them with distributable alternatives; include their notices and provenance.
- Assemble the full player folder layout, including the loading helper/resource pair, and validate completeness against explicit file/hash manifests.
- Provide a first-install/update path that closes GTA/SA-MP, verifies supported stock prerequisites, backs up owned files, rolls back failures and preserves player settings/locations.
- Complete [fresh player installation QA](PLAYER_INSTALL_QA.md) and native Windows clean-install testing, and state the actual supported platforms in the notes. The owner has already approved the existing 0.2.35 artwork build; that does not replace testing the downloaded package.
- Add and test player packaging before changing the download status. Editing `player_installable` alone cannot enable it: the current packager refuses player output.

Then prepare a new draft prerelease for player testing. After its required QA, publish a stable version and update the README's player download link. Prerequisites remain separate. GitHub Packages is unused because these downloads are ZIP release assets.

GitHub references: [releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases), [draft/prerelease CLI](https://cli.github.com/manual/gh_release_create), [workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts).
