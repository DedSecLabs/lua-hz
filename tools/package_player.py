#!/usr/bin/env python3
"""Build the player archive: Lua, current visuals, native helper, and installer.

Asset bytes are read from an explicit local resource folder. They are not
stored in the git source tree. Older resource versions are ignored.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import zipfile

from package_base import ROOT, base_payload, sha

GROUPS = (
    'fonts', 'sa_map', 'weaponicons', 'hud-v0218', 'dashboard-v0221',
    'portraits-v0222', 'ui-v0212', 'native-v0232', 'loading-v0233',
)
REQUIRED = (
    'moonloader/resource/horizonbase/hud-v0218/hud-font.png',
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
        output = subprocess.check_output(['git', 'tag', '-l', 'v*-player'], cwd=ROOT, text=True)
    except (OSError, subprocess.CalledProcessError):
        return None
    current = 'v' + version + '-player'
    tags = [tag for tag in output.split() if tag != current and re.fullmatch(r'v[0-9.]+-player', tag)]
    if not tags:
        return None
    def numbers(tag):
        return tuple(int(part) for part in re.findall(r'\d+', tag))
    return sorted(tags, key=numbers)[-1]


def change_notes(version):
    previous = previous_player_tag(version)
    current = 'v' + version + '-player'
    log = ''
    if previous:
        try:
            log = subprocess.check_output(
                ['git', 'log', '--no-merges', '--pretty=%s', previous + '..HEAD'],
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
        bullets.append('* Player release.')
    compare = ''
    if previous:
        compare = '\n**Full Changelog**: https://github.com/DedSecLabs/luahz/compare/' + previous + '...' + current + '\n'
    return '## What\'s Changed\n\n' + '\n'.join(bullets) + '\n' + compare


def install_notes(version):
    return f'''# LuaHZ {version} — player release

One download for Linux and Windows. It contains the HUD font, Quickmap, portraits, native visuals, and loading artwork. GTA, SA-MP, CLEO, MoonLoader, SAMPFUNCS, and mimgui stay separate. The verified SAMP.Lua files are included.

Close GTA and the SA-MP browser. Extract this ZIP outside the game folder.

**Windows:** copy `payload/moonloader` into the GTA folder, merging it with the existing `moonloader` folder. Copy `payload/LuaHZLoading.asi` next to `gta_sa.exe`.

**Linux/Wine:** from the extracted folder, run:

```sh
bash install.sh "/path/to/GTA San Andreas"
```

The path must contain `gta_sa.exe`. Join samp.hzgaming.net:7777. F9 opens settings, I opens Character Status, M opens Quickmap, and X toggles cruise while driving.
'''.encode()


def package(output, revision, resources, asi):
    if output.exists() or not re.fullmatch('[0-9a-f]{40}', revision):
        raise ValueError('Use a new output directory and full Git revision')
    payload, license_text, version, deps = base_payload()
    add_visuals(payload, resources, asi)
    files = {name: sha(data) for name, data in sorted(payload.items())}
    result = {
        'version': version, 'tag': 'v' + version + '-player', 'edition': 'player',
        'source_revision': revision, 'files': files,
        'includes': list(GROUPS) + ['LuaHZLoading.asi'],
        'excluded': ['GTA', 'SA-MP', 'CLEO', 'MoonLoader', 'SAMPFUNCS', 'mimgui', 'older resource versions'],
    }
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
    required = ['gta_sa.exe', 'samp.dll', 'SAMPFUNCS.asi', 'MoonLoader.asi', 'vorbisFile.dll', 'vorbisHooked.dll']
    (work / 'PREREQUISITES.sha256').write_text(''.join(deps['runtime_binaries'][name]['sha256'] + '  ' + name + '\n' for name in required))
    for script in ('base_install.sh', 'base_restore.sh', 'base_install.ps1', 'base_restore.ps1'):
        target = script.removeprefix('base_')
        (work / target).write_bytes((ROOT / 'tools' / script).read_bytes())
    (work / 'INSTALL.md').write_bytes(install_notes(version))
    (work / 'release-manifest.json').write_text(json.dumps(result, indent=2) + '\n')
    zip_path = output / (work.name + '.zip')
    with zipfile.ZipFile(zip_path, 'w') as archive:
        for path in sorted(work.rglob('*')):
            if not path.is_file():
                continue
            mode = zipfile.ZIP_STORED if path.suffix.lower() in {'.txd', '.enc', '.dll', '.asi'} else zipfile.ZIP_DEFLATED
            archive.write(path, path.relative_to(output), compress_type=mode)
    notes = change_notes(version) + '\n' + install_notes(version).decode() + f'\nSource commit: {revision}\nFiles: {len(files)}\n'
    (output / 'RELEASE_NOTES.md').write_text(notes)
    (output / 'release-manifest.json').write_text(json.dumps({key: result[key] for key in ('version', 'tag', 'edition', 'source_revision', 'includes')}, indent=2) + '\n')
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
