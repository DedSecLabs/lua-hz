"""Transactional base installer checks on disposable game fixtures."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class BaseInstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.game = self.root / 'game with spaces'
        self.bundle = self.root / 'bundle'
        self.game.mkdir(); self.bundle.mkdir()
        for name in ('install', 'restore'):
            shutil.copy2(ROOT / ('tools/base_' + name + '.sh'), self.bundle / (name + '.sh'))
        data = {'moonloader/HorizonBase.lua': b'entry', 'moonloader/lib/horizonbase/module.lua': b'module',
                'moonloader/resource/horizonbase/ui/icon.png': b'fixture icon',
                'moonloader/lib/samp/events.lua': b'patched library'}
        hashes = []
        for name, content in data.items():
            p = self.bundle / 'payload' / name
            p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(content)
            hashes.append(hashlib.sha256(content).hexdigest() + '  ' + name + '\n')
        (self.bundle / 'FILES.sha256').write_text(''.join(hashes))
        (self.game / 'gta_sa.exe').write_bytes(b'fixture game')
        (self.bundle / 'PREREQUISITES.sha256').write_text(hashlib.sha256(b'fixture game').hexdigest() + '  gta_sa.exe\n')
        for name in ('moonloader.lua', 'vkeys.lua', 'windows/message.lua', 'mimgui/init.lua', 'mimgui/cimguidx9.dll', 'samp/events.lua'):
            p = self.game / 'moonloader/lib' / name
            p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(b'original')
        self.settings = self.game / 'moonloader/config/player.ini'
        self.settings.parent.mkdir(); self.settings.write_bytes(b'personal setting')

    def run_script(self, path, env=None, upgrade=False):
        args = ['bash', str(path), str(self.game)] + (['--upgrade'] if upgrade else [])
        return subprocess.run(args, capture_output=True, text=True, env=env)

    def test_upgrade_and_recovery_preserve_settings_saved_locations_and_unrelated_files(self):
        self.assertEqual(self.run_script(self.bundle / 'install.sh').returncode, 0)
        entry = self.game / 'moonloader/HorizonBase.lua'
        entry.write_bytes(b'previous release entry')
        places = self.settings.parent / 'luahz-locations.json'
        places.write_bytes(b'{"saved": ["home"]}')
        unrelated = self.game / 'moonloader/another-mod.lua'
        unrelated.write_bytes(b'unrelated mod')
        result = self.run_script(self.bundle / 'install.sh', upgrade=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(entry.read_bytes(), b'entry')
        self.assertEqual(self.settings.read_bytes(), b'personal setting')
        self.assertEqual(places.read_bytes(), b'{"saved": ["home"]}')
        self.assertEqual(unrelated.read_bytes(), b'unrelated mod')
        backup = max((self.game / 'LuaHZ-backups').iterdir(), key=lambda p: p.stat().st_mtime_ns)
        self.assertEqual(self.run_script(backup / 'restore.sh').returncode, 0)
        self.assertEqual(entry.read_bytes(), b'previous release entry')
        self.assertEqual(places.read_bytes(), b'{"saved": ["home"]}')

    def test_failed_upgrade_restores_previous_build(self):
        self.assertEqual(self.run_script(self.bundle / 'install.sh').returncode, 0)
        entry = self.game / 'moonloader/HorizonBase.lua'
        entry.write_bytes(b'previous build')
        mock = self.root / 'bin'; mock.mkdir()
        cp = shutil.which('cp')
        (mock / 'cp').write_text('#!/bin/sh\ncase "$*" in *payload/moonloader/lib/samp/events.lua*) exit 71;; esac\nexec ' + cp + ' "$@"\n')
        (mock / 'cp').chmod(0o755)
        env = {**os.environ, 'PATH': str(mock) + ':' + os.environ['PATH']}
        self.assertNotEqual(self.run_script(self.bundle / 'install.sh', env, upgrade=True).returncode, 0)
        self.assertEqual(entry.read_bytes(), b'previous build')
        self.assertEqual(self.settings.read_bytes(), b'personal setting')

    def test_upgrade_requires_existing_install_and_refuses_config_payload(self):
        self.assertNotEqual(self.run_script(self.bundle / 'install.sh', upgrade=True).returncode, 0)
        self.assertFalse((self.game / 'LuaHZ-backups').exists())
        name = 'moonloader/config/player.ini'
        p = self.bundle / 'payload' / name;p.parent.mkdir(parents=True);p.write_bytes(b'overwrite')
        with (self.bundle / 'FILES.sha256').open('a') as f:
            f.write(hashlib.sha256(b'overwrite').hexdigest() + '  ' + name + '\n')
        self.assertNotEqual(self.run_script(self.bundle / 'install.sh').returncode, 0)
        self.assertFalse((self.game / 'LuaHZ-backups').exists())
        self.assertEqual(self.settings.read_bytes(), b'personal setting')

    def test_install_restore_preserves_preferences_and_original_library(self):
        result = self.run_script(self.bundle / 'install.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.game / 'moonloader/lib/samp/events.lua').read_bytes(), b'patched library')
        self.assertNotEqual(self.run_script(self.bundle / 'install.sh').returncode, 0)
        backup = next((self.game / 'LuaHZ-backups').iterdir())
        result = self.run_script(backup / 'restore.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.game / 'moonloader/lib/samp/events.lua').read_bytes(), b'original')
        self.assertFalse((self.game / 'moonloader/HorizonBase.lua').exists())
        self.assertEqual(self.settings.read_bytes(), b'personal setting')
        self.assertEqual(self.run_script(self.bundle / 'install.sh').returncode, 0)

    def test_required_streaming_fix_is_checked_before_any_game_write(self):
        checks = self.bundle / 'PREREQUISITES.sha256'
        data = b'fixture SilentPatch ASI'
        checks.write_text(checks.read_text() + hashlib.sha256(data).hexdigest() + '  SilentPatchSA.asi\n')
        self.assertNotEqual(self.run_script(self.bundle / 'install.sh').returncode, 0)
        self.assertFalse((self.game / 'LuaHZ-backups').exists())
        (self.game / 'SilentPatchSA.asi').write_bytes(b'wrong build')
        self.assertNotEqual(self.run_script(self.bundle / 'install.sh').returncode, 0)
        self.assertFalse((self.game / 'LuaHZ-backups').exists())
        (self.game / 'SilentPatchSA.asi').write_bytes(data)
        self.assertEqual(self.run_script(self.bundle / 'install.sh').returncode, 0)

    def test_tampered_payload_and_symlink_refused_before_writing(self):
        p = self.bundle / 'payload/moonloader/HorizonBase.lua'
        original = p.read_bytes(); p.write_bytes(b'tampered')
        self.assertNotEqual(self.run_script(self.bundle / 'install.sh').returncode, 0)
        self.assertFalse((self.game / 'LuaHZ-backups').exists())
        p.write_bytes(original)
        (self.game / 'LuaHZ-backups').symlink_to(self.bundle, target_is_directory=True)
        self.assertNotEqual(self.run_script(self.bundle / 'install.sh').returncode, 0)
        self.assertFalse((self.game / 'moonloader/HorizonBase.lua').exists())

    def test_failed_copy_rolls_back_and_recovery_protects_modified_files(self):
        mock = self.root / 'bin'; mock.mkdir()
        cp = shutil.which('cp')
        (mock / 'cp').write_text('#!/bin/sh\ncase "$*" in *payload/moonloader/lib/samp/events.lua*) exit 71;; esac\nexec ' + cp + ' "$@"\n')
        (mock / 'cp').chmod(0o755)
        env = {**os.environ, 'PATH': str(mock) + ':' + os.environ['PATH']}
        self.assertNotEqual(self.run_script(self.bundle / 'install.sh', env).returncode, 0)
        self.assertEqual((self.game / 'moonloader/lib/samp/events.lua').read_bytes(), b'original')
        self.assertFalse((self.game / 'moonloader/HorizonBase.lua').exists())
        self.assertEqual(self.run_script(self.bundle / 'install.sh').returncode, 0)
        backup = sorted((self.game / 'LuaHZ-backups').iterdir(), key=lambda p: p.stat().st_mtime_ns)[-1]
        (self.game / 'moonloader/HorizonBase.lua').write_bytes(b'user changed')
        self.assertNotEqual(self.run_script(backup / 'restore.sh').returncode, 0)
        self.assertEqual((self.game / 'moonloader/HorizonBase.lua').read_bytes(), b'user changed')

if __name__ == '__main__':
    unittest.main()
