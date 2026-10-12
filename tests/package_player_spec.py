"""Player archive accepts only the current visual groups."""
from pathlib import Path
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from package_player import REQUIRED, ROOT, add_visuals, prerequisite_checksums, previous_player_tag, release_notes, verify_source_revision


class PlayerPackageTests(unittest.TestCase):
    def test_notes_use_required_sections_exact_revision_and_file_count(self):
        revision = 'a' * 40
        with patch('package_player.change_notes', return_value="## What's Changed\n\n* Source change\n\n**Full Changelog**: comparison\n"):
            notes = release_notes('0.4.0-rc.5', revision, 679)
        headings = [line for line in notes.splitlines() if line.startswith('## ')]
        self.assertEqual(headings, ['## Mod Changes', "## What's Changed", '## Installation'])
        self.assertNotIn('# LuaHZ', notes)
        self.assertIn('commit/' + revision, notes)
        self.assertIn('**Files**: 679', notes)
        self.assertIn('LuaHZ-0.4.0-rc.5-player.zip', notes)
        self.assertIn('--upgrade', notes)
        self.assertIn('-Upgrade', notes)
        self.assertIn('U opens character Quick Actions', notes)
        self.assertIn('K opens Vehicle', notes)
        self.assertIn('Hold Alt to click', notes)

    def test_previous_release_includes_stable_tags_but_excludes_candidates_and_future_tags(self):
        tags = 'v0.2.39-player\nv0.3.0-rc.1\nv0.3.0\nv0.4.0\nv0.2.35-source-preview\n'
        with patch('package_player.subprocess.check_output', return_value=tags):
            self.assertEqual(previous_player_tag('0.3.0-rc.2'), 'v0.2.39-player')
            self.assertEqual(previous_player_tag('0.3.1'), 'v0.3.0')
            self.assertEqual(previous_player_tag('0.4.0-rc.5'), 'v0.3.0')

    def test_package_rejects_dirty_or_mismatched_source_commit(self):
        revision = 'a' * 40
        with patch('package_player.subprocess.check_output', side_effect=[revision, ' M src/HorizonBase.lua\n']):
            with self.assertRaisesRegex(ValueError, 'not clean'):
                verify_source_revision(revision)
        with patch('package_player.subprocess.check_output', return_value='b' * 40):
            with self.assertRaisesRegex(ValueError, 'current checked'):
                verify_source_revision(revision)

    def test_generated_prerequisites_pin_the_external_streaming_fix(self):
        deps = json.loads((ROOT / 'manifests/dependencies.json').read_text())
        lines = prerequisite_checksums(deps)
        self.assertIn(deps['runtime_binaries']['SilentPatchSA.asi']['sha256'] + '  SilentPatchSA.asi\n', lines)
        self.assertFalse(deps['runtime_binaries']['SilentPatchSA.asi']['bundled'])

    def test_current_groups_are_added_and_old_or_provenance_files_are_not(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            resources = root / 'horizonbase'
            for name in ('fonts/Rubik/Rubik-Regular.ttf', 'sa_map/1.jpg', 'sa_map/36.jpg',
                         'weaponicons/0.png', 'hud-v0218/hud-font.png', 'dashboard-v031/car-gear.png',
                         'portraits-v0222/1.png', 'ui-v0212/radar_centre.png',
                         'native-v0232/LuaHZVisuals.dll', 'loading-v0233/loading.enc',
                         'loading-v0233/SOURCE.json', 'ui-v027/old.png'):
                path = resources / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'MZ' if name.endswith('.dll') else b'asset-' + name.encode())
            asi = root / 'LuaHZLoading.asi'
            asi.write_bytes(b'MZ-helper')
            payload = {}
            with self.assertRaises(ValueError):
                add_visuals(payload, resources, asi)
            self.assertNotIn('moonloader/resource/horizonbase/ui-v027/old.png', payload)
            self.assertNotIn('moonloader/resource/horizonbase/loading-v0233/SOURCE.json', payload)
            self.assertFalse(any(name.endswith('SOURCE.json') for name in payload))

    def test_required_names_cover_the_player_visible_files(self):
        self.assertIn('LuaHZLoading.asi', REQUIRED)
        self.assertTrue(any(name.endswith('hud-font.png') for name in REQUIRED))
        self.assertTrue(any(name.endswith('loading.enc') for name in REQUIRED))


if __name__ == '__main__':
    unittest.main()
