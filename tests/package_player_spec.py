"""Player archive accepts only the current visual groups."""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from package_player import REQUIRED, add_visuals


class PlayerPackageTests(unittest.TestCase):
    def test_current_groups_are_added_and_old_or_provenance_files_are_not(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            resources = root / 'horizonbase'
            for name in ('fonts/Rubik/Rubik-Regular.ttf', 'sa_map/1.jpg', 'sa_map/36.jpg',
                         'weaponicons/0.png', 'hud-v0218/hud-font.png', 'dashboard-v0221/car-gear.png',
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
