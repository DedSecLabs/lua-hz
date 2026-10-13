#!/usr/bin/env python3
"""Build the player archive: Lua, current visuals, native helper, and installer.

Asset bytes are read from the explicit player resource folder. Older resource
versions are ignored. Release archives must identify a clean source commit.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import zipfile

from package_base import ROOT, base_payload, prerequisite_checksums, sha

GROUPS = (
    'fonts', 'sa_map', 'weaponicons', 'hud-v0218', 'dashboard-v031', 'vehicle-v040',
    'portraits-v0222', 'ui-v0212', 'native-v0232', 'loading-v0233',
)
REQUIRED = (
    'moonloader/resource/horizonbase/hud-v0218/hud-font.png',
    'moonloader/resource/horizonbase/dashboard-v031/car-door-lock.png',
    'moonloader/resource/horizonbase/dashboard-v031/car-door-lock-open.png',
    'moonloader/resource/horizonbase/dashboard-v031/car-gear.png',
    'moonloader/resource/horizonbase/dashboard-v031/run.png',
    'moonloader/resource/horizonbase/dashboard-v031/swimming-filled.png',
    'moonloader/resource/horizonbase/vehicle-v040/engine.png',
    'moonloader/resource/horizonbase/vehicle-v040/lights.png',
    'moonloader/resource/horizonbase/vehicle-v040/window.png',
    'moonloader/resource/horizonbase/vehicle-v040/hood.png',
    'moonloader/resource/horizonbase/vehicle-v040/trunk.png',
    'moonloader/resource/horizonbase/vehicle-v040/key.png',
    'moonloader/resource/horizonbase/vehicle-v040/users.png',
    'moonloader/resource/horizonbase/vehicle-v040/garage.png',
    'moonloader/resource/horizonbase/sa_map/1.jpg',
    'moonloader/resource/horizonbase/sa_map/36.jpg',
    'moonloader/resource/horizonbase/ui-v0212/radar_centre.png',
    'moonloader/resource/horizonbase/fonts/Rubik/Rubik-Regular.ttf',
    'moonloader/resource/horizonbase/native-v0232/LuaHZVisuals.dll',
    'moonloader/resource/horizonbase/loading-v0233/loading.enc',
    'LuaHZLoading.asi',
)


def add_visuals(payload, resources, asi):
    if not resources.is_dir():
        raise ValueError('Resource folder is missing')
    for group in GROUPS:
        folder = resources / group
        if not folder.is_dir():
            raise ValueError('Missing current resource group: ' + group)
        for path in sorted(folder.rglob('*')):
            if path.is_symlink() or not path.is_file() or path.name.endswith('SOURCE.json'):
                continue
            relative = 'moonloader/resource/horizonbase/' + path.relative_to(resources).as_posix()
            if not relative.startswith('moonloader/resource/horizonbase/' + group + '/'):
                raise ValueError('Resource path escaped its group: ' + relative)
            payload[relative] = path.read_bytes()
    data = asi.read_bytes()
    if data[:2] != b'MZ':
        raise ValueError('LuaHZLoading.asi is not a Windows executable')
    payload['LuaHZLoading.asi'] = data
    dll = payload['moonloader/resource/horizonbase/native-v0232/LuaHZVisuals.dll']
    if dll[:2] != b'MZ':
        raise ValueError('LuaHZVisuals.dll is not a Windows executable')
    expected = json.loads((ROOT / 'manifests/dependencies.json').read_text())['native_loading_artifact']['resource_sha256']
    artwork = payload['moonloader/resource/horizonbase/loading-v0233/loading.enc']
    if sha(artwork) != expected:
        raise ValueError('loading.enc does not match the recorded artwork fingerprint')
    missing = [name for name in REQUIRED if name not in payload]
    if missing:
        raise ValueError('Player archive is incomplete: ' + ', '.join(missing))
    for name, data in payload.items():
        if b'/home/' in data or b'Documents/ChatGPT' in data:
            raise ValueError('Personal path in player file: ' + name)
    return payload


def previous_player_tag(version):
    try:
        output = subprocess.check_output(['git', 'tag', '-l', 'v*'], cwd=ROOT, text=True)
    except (OSError, subprocess.CalledProcessError):
        return None
    core = tuple(int(part) for part in version.split('-')[0].split('.'))
    tags = [tag for tag in output.split()
            if re.fullmatch(r'v\d+\.\d+\.\d+(?:-player)?', tag)
            and tuple(int(part) for part in tag.removeprefix('v').removesuffix('-player').split('.')) < core]
    if not tags:
        return None
    def numbers(tag):
        return tuple(int(part) for part in re.findall(r'\d+', tag))
    return sorted(tags, key=numbers)[-1]


def change_notes(version, revision):
    previous = previous_player_tag(version)
    current = 'v' + version
    log = ''
    if previous:
        try:
            log = subprocess.check_output(
                ['git', 'log', '--no-merges', '--pretty=%s', previous + '..' + revision],
                cwd=ROOT, text=True)
        except (OSError, subprocess.CalledProcessError):
            log = ''
    bullets = []
    for subject in log.splitlines():
        subject = subject.strip()
        if not subject:
            continue
        match = re.fullmatch(r'([a-z]+)(?:\([^)]+\))?: (.+)', subject)
        if match:
            bullets.append('* **' + match.group(1) + '**: ' + match.group(2))
        else:
            bullets.append('* ' + subject)
    if not bullets:
        bullets.append('* No source commits since the previous player release.')
    compare = ''
    if previous:
        compare = '\n**Full Changelog**: https://github.com/DedSecLabs/luahz/compare/' + previous + '...' + current + '\n'
    return '## What\'s Changed\n\n' + '\n'.join(bullets) + '\n' + compare


def install_notes(version):
    return f'''## Installation

One download for Linux and Windows. It contains the HUD font, Quickmap, portraits, native visuals, and loading artwork. GTA, SA-MP, CLEO, SilentPatchSA Build 34.1, MoonLoader, SAMPFUNCS, and mimgui stay separate. The verified SAMP.Lua files are included. Install the tested prerequisites linked in the repository README first.

Classic SA-MP 0.3.7 R5 remains supported. Starting with 0.4.1, [open.mp launcher 1.6.1](https://open.mp/downloads/launcher) is an optional alternative with native client build 6 and the verified R5 client. Point it at the GTA folder and select 0.3.7 R5. Other SA-MP versions and unrecognized open.mp client builds are outside the native compatibility scope. open.mp uses F9 for its browser: open `/luahz` and assign F12 or another available settings shortcut. Preferences are not changed automatically.

Close GTA and both multiplayer launchers. Extract this ZIP outside the game folder.

The **GTA folder** contains `gta_sa.exe`. The installer verifies the payload and supported prerequisite hashes, backs up files it replaces, and prints a recovery command. Preferences and saved locations under `moonloader/config` are not included or overwritten.

**Windows (PowerShell):** from the extracted folder, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\\install.ps1 "C:\\Games\\GTA San Andreas"
```

To upgrade an existing LuaHZ installation, add `-Upgrade`. Keep the backup until the new build works. Windows open.mp loading, HUD/browser separation and settings input were owner-tested in a local trial. Full Windows feature/server-switching QA and the new combined helper through classic SA-MP remain pending. Exact archive acceptance is recorded separately; previous Linux/Wine release QA does not certify a new candidate.

**Linux/Wine:** from the extracted folder, run:

```sh
bash install.sh "/path/to/GTA San Andreas"
```

To upgrade, run `bash install.sh "/path/to/GTA San Andreas" --upgrade`. Existing resource groups not used by this build are left in place; recovery restores overwritten files and removes files added by this installation. Install SilentPatchSA Build 34.1 separately before upgrading from 0.2.39.

Join samp.hzgaming.net:7777. F9 opens settings, I opens Character Status, M opens Quickmap, U opens character Quick Actions, K opens Vehicle, and X toggles cruise while driving. Hold Alt to click the Vehicle panel; release Alt for mouse/camera control. K or Escape closes it. Shortcuts are configurable in F9; existing key assignments are preserved.

Download `LuaHZ-{version}-player.zip` to install the mod. The “Source code” archives are for developers.
'''.encode()


def release_notes(version, revision, file_count):
    path = ROOT / 'docs/releases' / (version.split('-')[0] + '.md')
    changes = path.read_text().strip()
    if not changes.startswith('## Mod Changes\n'):
        raise ValueError('Player notes must start with Mod Changes')
    return (changes + '\n\n' + change_notes(version, revision) + '\n'
            + install_notes(version).decode() + '\n'
            + f'**Source commit**: [{revision}](https://github.com/DedSecLabs/luahz/commit/{revision})\n'
            + f'**Files**: {file_count}\n')


def verify_source_revision(revision):
    actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if actual != revision:
        raise ValueError('Package the current checked source commit')
    status = subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=normal'], cwd=ROOT, text=True)
    if status.strip():
        raise ValueError('Commit the release inputs before packaging; working tree is not clean')


def package(output, revision, resources, asi):
    if output.exists() or not re.fullmatch('[0-9a-f]{40}', revision):
        raise ValueError('Use a new output directory and full Git revision')
    verify_source_revision(revision)
    if resources.resolve() != (ROOT / 'player-resources').resolve() or asi.resolve() != (resources / 'LuaHZLoading.asi').resolve():
        raise ValueError('Player releases use only the committed player-resources inputs')
    payload, license_text, version, deps = base_payload()
    if "script_version('" + version + "')" not in payload['moonloader/HorizonBase.lua'].decode():
        raise ValueError('Release and Lua versions must match')
    add_visuals(payload, resources, asi)
    files = {name: sha(data) for name, data in sorted(payload.items())}
    result = {
        'version': version, 'tag': 'v' + version, 'edition': 'player',
        'source_revision': revision, 'files': files,
        'includes': list(GROUPS) + ['LuaHZLoading.asi'],
        'excluded': ['GTA', 'SA-MP', 'CLEO', 'SilentPatchSA', 'MoonLoader', 'SAMPFUNCS', 'mimgui', 'older resource versions'],
    }
    release_name = json.loads((ROOT / 'manifests/release.json').read_text()).get('release_name')
    if release_name is not None:
        if not isinstance(release_name, str) or not release_name.strip() or '\n' in release_name or '\r' in release_name:
            raise ValueError('Release name must be nonempty text on one line')
        result['release_name'] = release_name.strip()
    notes = release_notes(version, revision, len(files))
    output.mkdir(parents=True)
    work = output / ('LuaHZ-' + version + '-player')
    for name, data in payload.items():
        path = work / 'payload' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    for name in ('LICENSE', 'THIRD_PARTY.md'):
        (work / name).write_bytes((ROOT / name).read_bytes())
    (work / 'SAMP-Lua-LICENSE.txt').write_bytes(license_text)
    (work / 'FILES.sha256').write_text(''.join(digest + '  ' + name + '\n' for name, digest in files.items()))
    (work / 'PREREQUISITES.sha256').write_text(prerequisite_checksums(deps))
    for script in ('base_install.sh', 'base_restore.sh', 'base_install.ps1', 'base_restore.ps1'):
        target = script.removeprefix('base_')
        (work / target).write_bytes((ROOT / 'tools' / script).read_bytes())
    (work / 'INSTALL.md').write_bytes(install_notes(version))
    (work / 'RELEASE_NOTES.md').write_text(notes)
    (work / 'release-manifest.json').write_text(json.dumps(result, indent=2) + '\n')
    zip_path = output / (work.name + '.zip')
    with zipfile.ZipFile(zip_path, 'w') as archive:
        for path in sorted(work.rglob('*')):
            if not path.is_file():
                continue
            mode = zipfile.ZIP_STORED if path.suffix.lower() in {'.txd', '.enc', '.dll', '.asi'} else zipfile.ZIP_DEFLATED
            archive.write(path, path.relative_to(output), compress_type=mode)
    (output / 'RELEASE_NOTES.md').write_text(notes)
    (output / 'release-manifest.json').write_text(json.dumps(result, indent=2) + '\n')
    attached = [zip_path.name, 'RELEASE_NOTES.md', 'release-manifest.json']
    (output / 'SHA256SUMS.txt').write_text(''.join(sha((output / name).read_bytes()) + '  ' + name + '\n' for name in attached))
    return {'archive': str(zip_path), 'files': len(files), 'bytes': zip_path.stat().st_size, 'tag': result['tag']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--resources', type=Path, required=True)
    parser.add_argument('--asi', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(package(args.output, args.revision, args.resources, args.asi), indent=2))
