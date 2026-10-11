#!/usr/bin/env python3
"""Build the minimal Linux/Wine player prerelease from public inputs only."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def prerequisite_checksums(deps):
    required = ['gta_sa.exe', 'samp.dll', 'SAMPFUNCS.asi', 'MoonLoader.asi',
                'vorbisFile.dll', 'vorbisHooked.dll', 'SilentPatchSA.asi']
    return ''.join(deps['runtime_binaries'][name]['sha256'] + '  ' + name + '\n' for name in required)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def base_payload():
    deps = json.loads((ROOT / 'manifests/dependencies.json').read_text())
    version = json.loads((ROOT / 'manifests/release.json').read_text())['version']
    payload = {}
    for p in sorted((ROOT / 'src').rglob('*.lua')):
        if p.is_symlink():
            raise ValueError('Symlink in source')
        payload['moonloader/' + p.relative_to(ROOT / 'src').as_posix()] = p.read_bytes()
    icons = json.loads((ROOT / 'assets/ui-v0212/sources.json').read_text())
    for name in [n + '.png' for n in icons] + ['LUCIDE-LICENSE.txt']:
        payload['moonloader/resource/horizonbase/ui-v0212/' + name] = (ROOT / 'assets/ui-v0212' / name).read_bytes()
    payload['moonloader/resource/horizonbase/ui-v0212/luahz-logo.png'] = (ROOT / 'assets/branding/luahz-logo.png').read_bytes()
    # Only FYP's explicitly MIT-licensed Lua library is bundled, not runtime binaries.
    request = urllib.request.Request(deps['runtime_libraries']['SAMP.Lua']['download'], headers={'User-Agent': 'LuaHZ-base-packager'})
    archive = zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(request, timeout=30).read()))
    library_count = 0
    for name in archive.namelist():
        if '/samp/' in name and name.endswith('.lua'):
            relative = name.split('/samp/', 1)[1]
            key = 'lib/samp/' + relative
            if key not in deps['runtime_lua_files']:
                raise ValueError('Unexpected SAMP.Lua file: ' + key)
            data = archive.read(name)
            if relative == 'events/handlers.lua':
                text = data.decode()
                for line in ('table.insert(data.materials, read_object_material(bs))', 'table.insert(data.materials_text, read_object_material_text(bs))'):
                    if text.count(line) != 1:
                        raise ValueError('Upstream material handler changed')
                    text = text.replace(line, line + '\n\t\t\tdata.actionType = actionType')
                data = text.encode()
            if sha(data) != deps['runtime_lua_files'][key]['sha256']:
                raise ValueError('SAMP.Lua baseline hash mismatch: ' + key)
            payload['moonloader/' + key] = data
            library_count += 1
    if library_count != 8:
        raise ValueError('Incomplete SAMP.Lua')
    licenses = [n for n in archive.namelist() if n.lower().endswith(('/license', '/license.txt', '/license.md'))]
    if len(licenses) != 1:
        raise ValueError('Missing upstream MIT notice')
    return payload, archive.read(licenses[0]), version, deps

def package(output, revision):
    if output.exists() or not re.fullmatch('[0-9a-f]{40}', revision):
        raise ValueError('Use a new output directory and full Git revision')
    payload, license_text, version, deps = base_payload()
    files = {name: sha(data) for name, data in sorted(payload.items())}
    result = {'version': version, 'tag': 'v' + version + '-base-preview', 'edition': 'base', 'source_revision': revision,
              'platform': 'Linux/Wine installer; 0.2.35 clean-install owner QA recorded. Windows untested.', 'files': files,
              'excluded': ['native graphics helpers', 'HD fonts/maps/icons', 'portrait pack', 'custom loading artwork'],
              'samp_lua': 'v2.0.4 plus verified material-handler adjustment; MIT notice included'}
    output.mkdir(parents=True)
    work = output / ('LuaHZ-' + version + '-base')
    for name, data in payload.items():
        path = work / 'payload' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    for name in ('LICENSE', 'THIRD_PARTY.md'):
        (work / name).write_bytes((ROOT / name).read_bytes())
    (work / 'SAMP-Lua-LICENSE.txt').write_bytes(license_text)
    (work / 'FILES.sha256').write_text(''.join(h + '  ' + n + '\n' for n, h in files.items()))
    (work / 'PREREQUISITES.sha256').write_text(prerequisite_checksums(deps))
    (work / 'install.sh').write_bytes((ROOT / 'tools/base_install.sh').read_bytes())
    (work / 'restore.sh').write_bytes((ROOT / 'tools/base_restore.sh').read_bytes())
    (work / 'install.ps1').write_bytes((ROOT / 'tools/base_install.ps1').read_bytes())
    (work / 'restore.ps1').write_bytes((ROOT / 'tools/base_restore.ps1').read_bytes())
    (work / 'INSTALL.md').write_bytes((ROOT / 'docs/BASE_INSTALL.md').read_bytes())
    (work / 'release-manifest.json').write_text(json.dumps(result, indent=2) + '\n')
    zip_path = output / (work.name + '.zip')
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as z:
        for p in sorted(work.rglob('*')):
            if p.is_file():
                z.write(p, p.relative_to(output))
    notes = f'''# LuaHZ {version} — base player preview

Download **{zip_path.name}**, extract it outside GTA and read INSTALL.md.
For a separate clean Linux/Wine GTA SA 1.0 US / SA-MP R5 installation.
Install the linked CLEO/ASI loader, SilentPatchSA Build 34.1, MoonLoader, SAMPFUNCS and mimgui prerequisites first.
Verified SAMP.Lua is included with its MIT notice; no manual Lua editing or compilation.

Includes HUD with fallback text, vehicle dashboard, settings, character statistics,
cruise controls and ordinary Horizon helpers. Uses stock native game fonts/radar/loading.
HD visuals, portrait previews and the Quickmap background are not included.
Quickmap is unavailable in this base edition; use the game's ESC map.

The shell installer verifies supported binary hashes, refuses an existing LuaHZ install,
backs up replaced library files and supports guarded recovery. Settings are not bundled.
Offline installation/rollback and source checks pass. The owner recorded a Linux/Wine
clean-install test for 0.2.35. This is not a claim of validated Windows support.
Source commit: {revision}
'''
    (output / 'RELEASE_NOTES.md').write_text(notes)
    (output / 'release-manifest.json').write_text(json.dumps(result, indent=2) + '\n')
    attached = [zip_path.name, 'RELEASE_NOTES.md', 'release-manifest.json']
    (output / 'SHA256SUMS.txt').write_text(''.join(sha((output / n).read_bytes()) + '  ' + n + '\n' for n in attached))
    return {'archive': str(zip_path), 'files': len(files), 'bytes': zip_path.stat().st_size, 'tag': result['tag']}

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--revision', required=True)
    a = p.parse_args()
    print(json.dumps(package(a.output, a.revision), indent=2))
