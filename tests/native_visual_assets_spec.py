from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import native_visual_assets as assets

class BaselineTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.game=Path(self.temp.name)/'game'
        (self.game/'moonloader/config').mkdir(parents=True)
        self.records={}
        for relative in sorted(assets.FILES):
            target=self.game/relative;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(('custom:'+relative).encode())
            backup=self.game/'original'/relative;backup.parent.mkdir(parents=True,exist_ok=True)
            backup.write_bytes(('stock:'+relative).encode())
            self.records[relative]={'original':str(backup),'original_sha256':assets.sha(backup),'current_sha256':assets.sha(target)}
        self.closed=patch.object(assets,'require_game_closed');self.closed.start()
    def tearDown(self):self.closed.stop();self.temp.cleanup()
    def test_switch_preserves_working_assets_and_restores_only_verified_baselines(self):
        info=assets.switch(self.game,self.records)
        for relative,item in self.records.items():
            self.assertEqual(assets.sha(self.game/relative),item['original_sha256'])
            self.assertEqual(assets.sha(Path(info['backup'])/relative),item['current_sha256'])
        with self.assertRaises(ValueError):assets.switch(self.game,self.records)
        resources=self.game/'moonloader/resource/horizonbase/native-v0232';resources.mkdir(parents=True)
        (resources/'LuaHZVisuals.dll').write_bytes(b'our helper')
        assets.restore(self.game)
        for relative,item in self.records.items():self.assertEqual(assets.sha(self.game/relative),item['current_sha256'])
        self.assertFalse(resources.exists())
        self.assertTrue((Path(info['backup'])/'disabled-native-v0232/LuaHZVisuals.dll').exists())
    def test_external_changes_and_unexpected_targets_are_rejected(self):
        target=self.game/'models/hud.txd';target.write_bytes(b'other mod changed it')
        with self.assertRaises(ValueError):assets.switch(self.game,self.records)
        self.assertEqual(target.read_bytes(),b'other mod changed it')
        records=dict(self.records);records['../outside']={}
        with self.assertRaises(ValueError):assets.switch(self.game,records)
    def test_mid_switch_failure_recovers_every_working_file(self):
        original=Path.rename;failed=False
        def failing(path,target):
            nonlocal failed
            if path.name=='hud.txd.luahz-native-base.tmp' and not failed:
                failed=True;raise OSError('simulated native switch failure')
            return original(path,target)
        with patch.object(Path,'rename',failing):
            with self.assertRaises(OSError):assets.switch(self.game,self.records)
        for relative,item in self.records.items():self.assertEqual(assets.sha(self.game/relative),item['current_sha256'])
        self.assertFalse((self.game/'moonloader/config/native-visuals-deploy.json').exists())
        self.assertFalse(list(self.game.rglob('*.tmp')))
