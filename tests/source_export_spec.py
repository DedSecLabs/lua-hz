from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import export_source

class ExportTests(unittest.TestCase):
    def test_public_source_omits_local_inputs_binaries_and_personal_state(self):
        with tempfile.TemporaryDirectory()as directory:
            root=Path(directory)/'project';root.mkdir()
            for relative in ['README.md','src/main.lua','.local/secret.ini','branding/art.png','build/game.exe','tools/__pycache__/cached.pyc']:
                p=root/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'fixture')
            result=export_source.export(Path(directory)/'export',root)
            self.assertEqual(set(result['files']),{'README.md','src/main.lua'})
    def test_unknown_radar_asset_is_rejected_before_export(self):
        with tempfile.TemporaryDirectory()as directory:
            root=Path(directory)/'project';p=root/'assets/ui-v0212/radar_CJ.png';p.parent.mkdir(parents=True);p.write_bytes(b'local art')
            out=Path(directory)/'export'
            with self.assertRaises(ValueError):export_source.export(out,root)
            self.assertFalse(out.exists())
