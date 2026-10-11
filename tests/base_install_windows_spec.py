"""PowerShell base installer checks. Skipped when pwsh is not installed."""
import hashlib
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PWSH = shutil.which('pwsh')


@unittest.skipUnless(PWSH, 'pwsh is not installed')
class WindowsBaseInstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.game = self.root / 'game with spaces'
        self.bundle = self.root / 'bundle'
        self.game.mkdir()
        self.bundle.mkdir()
        for name in ('install', 'restore'):
            shutil.copy2(ROOT / ('tools/base_' + name + '.ps1'), self.bundle / (name + '.ps1'))
        data = {'moonloader/HorizonBase.lua': b'entry', 'moonloader/lib/horizonbase/module.lua': b'module',
                'moonloader/resource/horizonbase/ui/icon.png': b'fixture icon',
                'moonloader/lib/samp/events.lua': b'patched library'}
        hashes = []
        for name, content in data.items():
            path = self.bundle / 'payload' / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
            hashes.append(hashlib.sha256(content).hexdigest() + '  ' + name + '\n')
        (self.bundle / 'FILES.sha256').write_text(''.join(hashes))
        (self.game / 'gta_sa.exe').write_bytes(b'fixture game')
        (self.bundle / 'PREREQUISITES.sha256').write_text(hashlib.sha256(b'fixture game').hexdigest() + '  gta_sa.exe\n')
        for name in ('moonloader.lua', 'vkeys.lua', 'windows/message.lua', 'mimgui/init.lua', 'mimgui/cimguidx9.dll', 'samp/events.lua'):
            path = self.game / 'moonloader/lib' / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'original')
        self.settings = self.game / 'moonloader/config/player.ini'
        self.settings.parent.mkdir()
        self.settings.write_bytes(b'personal setting')

    def run_script(self, path, upgrade=False):
        args = [PWSH, '-NoProfile', '-File', str(path), str(self.game)] + (['-Upgrade'] if upgrade else [])
        return subprocess.run(args, capture_output=True, text=True)

    def test_upgrade_and_recovery_preserve_saved_preferences(self):
        self.assertEqual(self.run_script(self.bundle / 'install.ps1').returncode, 0)
        entry = self.game / 'moonloader/HorizonBase.lua';entry.write_bytes(b'previous build')
        places = self.settings.parent / 'luahz-locations.json';places.write_bytes(b'saved place')
        result = self.run_script(self.bundle / 'install.ps1', upgrade=True)
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(entry.read_bytes(), b'entry')
        self.assertEqual(self.settings.read_bytes(), b'personal setting')
        self.assertEqual(places.read_bytes(), b'saved place')
        backup = max((self.game / 'LuaHZ-backups').iterdir(), key=lambda p: p.stat().st_mtime_ns)
        self.assertEqual(self.run_script(backup / 'restore.ps1').returncode, 0)
        self.assertEqual(entry.read_bytes(), b'previous build')

    def test_config_payload_is_refused_before_writing(self):
        name = 'moonloader/config/player.ini'
        p = self.bundle / 'payload' / name;p.parent.mkdir(parents=True);p.write_bytes(b'overwrite')
        with (self.bundle / 'FILES.sha256').open('a') as f:
            f.write(hashlib.sha256(b'overwrite').hexdigest() + '  ' + name + '\n')
        self.assertNotEqual(self.run_script(self.bundle / 'install.ps1').returncode, 0)
        self.assertFalse((self.game / 'LuaHZ-backups').exists())
        self.assertEqual(self.settings.read_bytes(), b'personal setting')

    def test_install_restore_preserves_preferences_and_original_library(self):
        result = self.run_script(self.bundle / 'install.ps1')
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual((self.game / 'moonloader/lib/samp/events.lua').read_bytes(), b'patched library')
        self.assertNotEqual(self.run_script(self.bundle / 'install.ps1').returncode, 0)
        backup = next((self.game / 'LuaHZ-backups').iterdir())
        result = self.run_script(backup / 'restore.ps1')
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual((self.game / 'moonloader/lib/samp/events.lua').read_bytes(), b'original')
        self.assertFalse((self.game / 'moonloader/HorizonBase.lua').exists())
        self.assertEqual(self.settings.read_bytes(), b'personal setting')
        self.assertEqual(self.run_script(self.bundle / 'install.ps1').returncode, 0)

    def test_tampered_payload_refused_before_writing(self):
        path = self.bundle / 'payload/moonloader/HorizonBase.lua'
        original = path.read_bytes()
        path.write_bytes(b'tampered')
        self.assertNotEqual(self.run_script(self.bundle / 'install.ps1').returncode, 0)
        self.assertFalse((self.game / 'LuaHZ-backups').exists())
        path.write_bytes(original)
        (self.game / 'LuaHZ-backups').symlink_to(self.bundle, target_is_directory=True)
        self.assertNotEqual(self.run_script(self.bundle / 'install.ps1').returncode, 0)
        self.assertFalse((self.game / 'moonloader/HorizonBase.lua').exists())

    def test_recovery_protects_modified_files(self):
        self.assertEqual(self.run_script(self.bundle / 'install.ps1').returncode, 0)
        backup = next((self.game / 'LuaHZ-backups').iterdir())
        (self.game / 'moonloader/HorizonBase.lua').write_bytes(b'user changed')
        self.assertNotEqual(self.run_script(backup / 'restore.ps1').returncode, 0)
        self.assertEqual((self.game / 'moonloader/HorizonBase.lua').read_bytes(), b'user changed')


if __name__ == '__main__':
    unittest.main()
