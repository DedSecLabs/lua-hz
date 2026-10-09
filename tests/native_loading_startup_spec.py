from pathlib import Path
import json
import sys
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from sampfuncs_loading_spec import fixture
import sampfuncs_loading as sf
import native_loading_bar as bar
import native_loading_startup as startup

class StartupInstallTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name);self.game=self.root/'game'
        config=self.game/'moonloader/config';config.mkdir(parents=True)
        self.original,_,_=fixture()
        self.patch_sf=patch.object(sf,'ORIGINAL_SHA',sf.sha(self.original));self.patch_sf.start()
        self.stock_game=b'original-game';self.patch_game=patch.object(bar,'ORIGINAL_SHA',sf.sha(self.stock_game));self.patch_game.start()
        self.closed=patch.object(startup,'require_game_closed');self.closed.start()
        art=self.root/'art.png';Image.new('RGB',(64,36),(32,128,240)).save(art)
        self.modified=sf.build_lossless(self.original,art)
        (self.game/'SAMPFUNCS.asi').write_bytes(self.modified);(self.game/'gta_sa.exe').write_bytes(b'game-with-bar')
        backups=self.game/'Loading screen backups';(backups/'sf').mkdir(parents=True);(backups/'bar').mkdir()
        (backups/'sf/SAMPFUNCS.asi').write_bytes(self.original);(backups/'bar/gta_sa.exe').write_bytes(self.stock_game)
        for name,folder,target in [('sampfuncs-loading-deploy.json','sf','SAMPFUNCS.asi'),('loading-bar-deploy.json','bar','gta_sa.exe')]:
            (config/name).write_text(json.dumps({'backup':str(backups/folder),'installed_sha256':startup.sha(self.game/target)}))
        self.helper=self.root/'LuaHZLoading.asi';self.helper.write_bytes(b'MZour-bootstrap')
        self.assets=self.root/'assets';self.assets.mkdir()
        metadata,_=sf.hd_resource(self.modified)
        (self.assets/'loading.enc').write_bytes(self.modified[metadata['offset']:metadata['offset']+metadata['bytes']])
    def tearDown(self):self.closed.stop();self.patch_sf.stop();self.patch_game.stop();self.temp.cleanup()
    def test_install_restores_stock_binaries_and_retains_exact_artwork_and_recovery(self):
        info=startup.install(self.game,self.helper,self.assets)
        self.assertEqual((self.game/'gta_sa.exe').read_bytes(),self.stock_game)
        self.assertEqual((self.game/'SAMPFUNCS.asi').read_bytes(),self.original)
        self.assertEqual((self.game/'moonloader/resource/horizonbase/loading-v0233/loading.enc').read_bytes(),(self.assets/'loading.enc').read_bytes())
        self.assertEqual((Path(info['backup'])/'SAMPFUNCS.asi').read_bytes(),self.modified)
        startup.restore(self.game)
        self.assertEqual((self.game/'SAMPFUNCS.asi').read_bytes(),self.modified)
        self.assertEqual((self.game/'gta_sa.exe').read_bytes(),b'game-with-bar')
        self.assertFalse((self.game/'LuaHZLoading.asi').exists())
    def test_changed_artwork_or_binary_is_not_overwritten(self):
        data=(self.assets/'loading.enc').read_bytes();(self.assets/'loading.enc').write_bytes(data[:-1]+bytes([data[-1]^1]))
        with self.assertRaises(ValueError):startup.install(self.game,self.helper,self.assets)
        self.assertEqual((self.game/'SAMPFUNCS.asi').read_bytes(),self.modified)
        (self.assets/'loading.enc').write_bytes(data);(self.game/'gta_sa.exe').write_bytes(b'external-change')
        with self.assertRaises(ValueError):startup.install(self.game,self.helper,self.assets)
        self.assertEqual((self.game/'gta_sa.exe').read_bytes(),b'external-change')
    def test_failed_receipt_recovers_binaries_and_removes_only_added_payload(self):
        actual=startup.write_atomic
        def failing(path,data):
            if path.name=='loading-startup-deploy.json':raise OSError('receipt failure')
            return actual(path,data)
        with patch.object(startup,'write_atomic',side_effect=failing):
            with self.assertRaises(OSError):startup.install(self.game,self.helper,self.assets)
        self.assertEqual((self.game/'SAMPFUNCS.asi').read_bytes(),self.modified)
        self.assertEqual((self.game/'gta_sa.exe').read_bytes(),b'game-with-bar')
        self.assertFalse((self.game/'LuaHZLoading.asi').exists())
        self.assertFalse((self.game/'moonloader/resource/horizonbase/loading-v0233').exists())
    def test_pair_update_keeps_stock_files_and_recovers_receipt_failure(self):
        startup.install(self.game,self.helper,self.assets)
        receipt=self.game/'moonloader/config/loading-startup-deploy.json';previous=receipt.read_bytes()
        old_helper=(self.game/'LuaHZLoading.asi').read_bytes()
        old_art=(self.assets/'loading.enc').read_bytes();new_art=bytearray(old_art);new_art[0]^=1
        (self.assets/'loading.enc').write_bytes(new_art);self.helper.write_bytes(b'MZupdated-fingerprint')
        real=startup.write_atomic;failed=False
        def failing(path,data):
            nonlocal failed
            if path==receipt and not failed:
                failed=True;raise OSError('simulated pair receipt failure')
            return real(path,data)
        with patch.object(startup,'write_atomic',side_effect=failing):
            with self.assertRaises(OSError):startup.update(self.game,self.helper,self.assets)
        self.assertEqual(receipt.read_bytes(),previous);self.assertEqual((self.game/'LuaHZLoading.asi').read_bytes(),old_helper)
        self.assertEqual((self.game/'moonloader/resource/horizonbase/loading-v0233/loading.enc').read_bytes(),old_art)
        info=startup.update(self.game,self.helper,self.assets)
        self.assertEqual((self.game/'gta_sa.exe').read_bytes(),self.stock_game)
        self.assertEqual((self.game/'SAMPFUNCS.asi').read_bytes(),self.original)
        self.assertTrue(Path(info['last_update_backup']).is_dir())
