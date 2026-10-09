#!/usr/bin/env python3
"""Package audited source and original native builds for a developer preview.

Never reads game installations, private resources or local QA ZIPs. A player
package is deliberately refused until a complete distribution path is added.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import tempfile
import zipfile

from export_source import ROOT, export

NATIVE_FILES = ('LuaHZVisuals.dll', 'LuaHZLoading.asi')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def check_native(path):
    if path.is_symlink():
        raise ValueError('Native build must be a regular file: ' + path.name)
    data = path.read_bytes()
    if len(data) < 64 or data[:2] != b'MZ':
        raise ValueError('Expected a built PE DLL: ' + path.name)
    offset = struct.unpack_from('<I', data, 60)[0]
    if offset < 64 or offset + 26 > len(data) or data[offset:offset + 4] != b'PE\0\0':
        raise ValueError('Invalid PE header: ' + path.name)
    machine = struct.unpack_from('<H', data, offset + 4)[0]
    characteristics = struct.unpack_from('<H', data, offset + 22)[0]
    magic = struct.unpack_from('<H', data, offset + 24)[0]
    if machine != 0x14c or magic != 0x10b or not characteristics & 0x2000:
        raise ValueError('Expected an x86 PE32 DLL: ' + path.name)
    return data


def package(output, native_dir, revision, root=ROOT, kind='developer-preview'):
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Provide the full source Git commit SHA')
    policy = json.loads((root / 'manifests/release.json').read_text())
    version = policy['version']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Invalid release version')
    if kind != 'developer-preview' or policy.get('package_kind') != kind or policy.get('player_installable') is not False:
        raise ValueError('Player packaging is not ready. See manifests/release.json and docs/RELEASING.md.')
    entry = (root / 'src/HorizonBase.lua').read_text()
    deployment = (root / 'tools/deploy.py').read_text()
    if "script_version('" + version + "')" not in entry or 'VERSION = "' + version + '"' not in deployment:
        raise ValueError('Release, Lua and deployment versions must match')
    if output.exists():
        raise ValueError('Output already exists; preserve it or choose a new directory')
    native = {name: check_native(native_dir / name) for name in NATIVE_FILES}
    name = 'LuaHZ-' + version + '-developer-preview'
    tag = 'v' + version + '-source-preview'
    start = f'''# LuaHZ {version} — developer preview

This download is for contributors and local testers. It is not a player installer.
The complete player ZIP is still being prepared. Check
https://github.com/DedSecLabs/lua-hz/releases for future player downloads.

Contents:
- source/: audited source, licensed UI assets, logo, tests and documentation.
- native-build/: our compiled x86 native helpers.

Do not copy this whole directory into GTA. Start with source/docs/DEVELOPMENT.md.
The native helpers require separately acquired, matching visual resources.
This download does not include those resources, GTA files or prerequisites.
Python/compiler tools are for contributors; players will not need to build code.

Source commit: {revision}
'''
    payload = {'START-HERE.md': start.encode()}
    with tempfile.TemporaryDirectory(prefix='luahz-release-source-') as temporary:
        source = Path(temporary) / 'source'
        source_info = export(source, root)
        for relative in source_info['files']:
            payload['source/' + relative] = (source / relative).read_bytes()
    payload.update({'native-build/' + filename: data for filename, data in native.items()})
    manifest = {
        'schema_version': 1, 'version': version, 'tag': tag,
        'package_kind': kind, 'player_installable': False, 'source_revision': revision,
        'archive': name + '.zip', 'source_file_count': source_info['file_count'],
        'files': {path: digest(data) for path, data in sorted(payload.items())},
        'player_release_blockers': policy['player_release_blockers'],
        'native_loading_artifact': json.loads((root / 'manifests/dependencies.json').read_text())['native_loading_artifact'],
    }
    notes = f'''# LuaHZ {version} — developer preview

**For contributors and local testers. A ready-to-install player mod is still pending.**

Download `{name}.zip` for the audited source and our compiled x86 native helpers.
Read `START-HERE.md` inside the ZIP before using it. `SHA256SUMS.txt` verifies
the attached files; `release-manifest.json` records every payload file and the
exact [source commit](https://github.com/DedSecLabs/lua-hz/commit/{revision}).

Prerequisites and external visual resources are acquired separately. The native
loading helper requires the matched loading resource; the compiled helper alone
does not reproduce the approved appearance. See the included installation and
development guides for the supported GTA SA 1.0 US / SA-MP R5 setup.

## Remaining player-release work

'''
    notes += '\n'.join('- ' + blocker for blocker in policy['player_release_blockers']) + '\n'
    # All validation and source scanning finish before creating any output.
    output.mkdir(parents=True)
    archive = output / manifest['archive']
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
        for path, data in sorted(payload.items()):
            item = zipfile.ZipInfo(name + '/' + path, date_time=(1980, 1, 1, 0, 0, 0))
            item.create_system = 3
            item.external_attr = 0o100644 << 16
            item.compress_type = zipfile.ZIP_DEFLATED
            bundle.writestr(item, data)
    manifest['archive_sha256'] = digest(archive.read_bytes())
    (output / 'release-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (output / 'RELEASE_NOTES.md').write_text(notes)
    names = (manifest['archive'], 'release-manifest.json', 'RELEASE_NOTES.md')
    (output / 'SHA256SUMS.txt').write_text(''.join(digest((output / p).read_bytes()) + '  ' + p + '\n' for p in names))
    return {key: manifest[key] for key in ('version', 'tag', 'archive', 'archive_sha256', 'player_installable')}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--native-dir', required=True, type=Path)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--kind', choices=('developer-preview', 'player'), default='developer-preview')
    args = parser.parse_args()
    try:
        result = package(args.output, args.native_dir, args.revision, kind=args.kind)
    except (ValueError, OSError, KeyError) as error:
        parser.exit(1, str(error) + '\n')
    print(json.dumps(result, indent=2))
