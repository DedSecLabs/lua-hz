from pathlib import Path
import hashlib
import json
import struct
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import package_release


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / 'project'
        data = {
            'README.md': '# Source',
            'src/HorizonBase.lua': "script_version('0.2.35')",
            'tools/deploy.py': 'VERSION = "0.2.35"',
            'manifests/release.json': json.dumps({'version': '0.2.35', 'package_kind': 'developer-preview', 'player_installable': False, 'player_release_blockers': ['External resources pending.']}),
            'manifests/dependencies.json': json.dumps({'native_loading_artifact': {'resource_fnv32': '0x12345678'}}),
            '.local/private.ini': 'private preferences',
            'branding/private.png': 'unreviewed art',
            'build/LuaHZ-local-QA.zip': 'private archive',
        }
        for relative, text in data.items():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        self.native = self.base / 'native'
        self.native.mkdir()
        binary = bytearray(128)
        binary[:2] = b'MZ'
        struct.pack_into('<I', binary, 60, 64)
        binary[64:68] = b'PE\0\0'
        struct.pack_into('<H', binary, 68, 0x14c)
        struct.pack_into('<H', binary, 86, 0x2000)
        struct.pack_into('<H', binary, 88, 0x10b)
        for name in package_release.NATIVE_FILES:
            (self.native / name).write_bytes(binary)
        self.output = self.base / 'output'

    def build(self, **kwargs):
        return package_release.package(self.output, self.native, 'a' * 40, root=self.root, **kwargs)

    def test_bundle_excludes_private_inputs_and_checksums_cover_payload(self):
        result = self.build()
        with zipfile.ZipFile(self.output / result['archive']) as archive:
            files = archive.namelist()
            self.assertFalse(any('/.local/' in name or '/branding/' in name or 'local-QA' in name for name in files))
            self.assertEqual(sum('/native-build/' in name for name in files), 2)
            manifest = json.loads((self.output / 'release-manifest.json').read_text())
            for path, expected in manifest['files'].items():
                actual = hashlib.sha256(archive.read('LuaHZ-0.2.35-developer-preview/' + path)).hexdigest()
                self.assertEqual(actual, expected)
        for line in (self.output / 'SHA256SUMS.txt').read_text().splitlines():
            expected, name = line.split('  ', 1)
            self.assertEqual(hashlib.sha256((self.output / name).read_bytes()).hexdigest(), expected)
        self.assertFalse(result['player_installable'])

    def test_player_package_is_refused_even_if_policy_is_edited(self):
        with self.assertRaisesRegex(ValueError, 'Player packaging'):
            self.build(kind='player')
        policy = self.root / 'manifests/release.json'
        data = json.loads(policy.read_text())
        data['player_installable'] = True
        policy.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'Player packaging'):
            self.build()
        self.assertFalse(self.output.exists())

    def test_invalid_native_or_wrong_architecture_never_creates_package(self):
        path = self.native / 'LuaHZLoading.asi'
        data = bytearray(path.read_bytes())
        struct.pack_into('<H', data, 68, 0x8664)
        path.write_bytes(data)
        with self.assertRaisesRegex(ValueError, 'x86'):
            self.build()
        self.assertFalse(self.output.exists())
        path.write_bytes(b'not a DLL')
        with self.assertRaisesRegex(ValueError, 'PE DLL'):
            self.build()

    def test_version_mismatch_and_existing_output_are_rejected(self):
        entry = self.root / 'src/HorizonBase.lua'
        entry.write_text("script_version('0.2.34')")
        with self.assertRaisesRegex(ValueError, 'versions must match'):
            self.build()
        entry.write_text("script_version('0.2.35')")
        self.output.mkdir()
        saved = self.output / 'keep.txt'
        saved.write_text('existing artifact')
        with self.assertRaisesRegex(ValueError, 'Output already exists'):
            self.build()
        self.assertEqual(saved.read_text(), 'existing artifact')

    def test_private_machine_path_is_rejected_before_output(self):
        (self.root / 'README.md').write_text('/home/' + 'amir/private-game')
        with self.assertRaisesRegex(ValueError, 'Personal machine path'):
            self.build()
        self.assertFalse(self.output.exists())

    def test_fixed_payload_is_deterministic(self):
        first = self.build()
        other = package_release.package(self.base / 'other', self.native, 'a' * 40, root=self.root)
        self.assertEqual(first['archive_sha256'], other['archive_sha256'])
