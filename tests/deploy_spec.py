import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

PROJECT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('deploy',PROJECT/'tools/deploy.py')
deploy=importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)

class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.base=Path(self.temp.name)
        self.root=self.base/'game/moonloader'
        for name in ['lib/moonloader.lua','lib/mimgui/init.lua','lib/samp/events.lua','LunaHZ.luac','config/lunahz.ini',
                     'resource/lunahz/sa_map/1.jpg','resource/lunahz/fonts/Rubik/Rubik-Regular.ttf']:
            p=self.root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'original')
        (self.root.parent/'SAMPFUNCS.asi').write_bytes(b'fake dependency')
        self.fake_project=self.base/'project'
        (self.fake_project/'src/lib/horizonbase').mkdir(parents=True)
        (self.fake_project/'src/HorizonBase.lua').write_bytes(b'new source')
        (self.fake_project/'src/lib/horizonbase/config.lua').write_bytes(b'new module')
        (self.fake_project/'THIRD_PARTY.md').write_text('license notices')
        asset_dir=self.fake_project/'assets'/Path(deploy.UI_ASSETS).name
        asset_dir.mkdir(parents=True)
        (asset_dir/'x.png').write_bytes(b'fake icon')
        (asset_dir/'LUCIDE-LICENSE.txt').write_text('icon license')
        (self.fake_project/'branding').mkdir()
        (self.fake_project/'branding/luahz-menu-icon-hz-v4.png').write_bytes(b'fake logo')
        self.project_patch=patch.object(deploy,'PROJECT',self.fake_project);self.project_patch.start()
        self.closed_patch=patch.object(deploy,'require_game_closed');self.closed_patch.start()
    def tearDown(self):
        self.closed_patch.stop();self.project_patch.stop();self.temp.cleanup()
    def test_stage_preserves_game(self):
        result=deploy.stage(self.root)
        self.assertEqual((self.root/'LunaHZ.luac').read_bytes(),b'original')
        self.assertFalse((self.root/'HorizonBase.lua').exists())
        self.assertEqual(result['map_tiles'],1)
    def test_install_restore_round_trip(self):
        deploy.install(self.root)
        self.assertFalse((self.root/'LunaHZ.luac').exists())
        self.assertEqual((self.root/'HorizonBase.lua').read_bytes(),b'new source')
        self.assertEqual((self.root/'config/lunahz.ini').read_bytes(),b'original')
        deploy.restore(self.root)
        self.assertEqual((self.root/'LunaHZ.luac').read_bytes(),b'original')
        self.assertFalse((self.root/'HorizonBase.lua').exists())
    def test_install_failure_restores_original(self):
        real=deploy.shutil.copytree
        def fail(source,destination,*a,**kw):
            if Path(source).as_posix().endswith('build/moonloader/lib/horizonbase'):
                Path(destination).mkdir(parents=True);(Path(destination)/'partial.lua').write_text('partial')
                raise OSError('injected copy failure')
            return real(source,destination,*a,**kw)
        with patch.object(deploy.shutil,'copytree',side_effect=fail):
            with self.assertRaises(OSError):deploy.install(self.root)
        self.assertTrue((self.root/'LunaHZ.luac').exists())
        self.assertFalse((self.root/'HorizonBase.lua').exists())
        self.assertFalse((self.root/'lib/horizonbase').exists())
    def test_restore_rejects_unexpected_paths(self):
        import json
        deploy.install(self.root)
        receipt=self.root/'config/horizonbase-deploy.json'
        info=json.loads(receipt.read_text());info['installed_paths'].append('../unexpected')
        receipt.write_text(json.dumps(info))
        with self.assertRaises(ValueError):deploy.restore(self.root)
        self.assertTrue((self.root/'HorizonBase.lua').exists())
    def test_update_preserves_original_backup_and_preferences(self):
        info=deploy.install(self.root)
        (self.fake_project/'src/HorizonBase.lua').write_bytes(b'updated source')
        deploy.update(self.root)
        self.assertEqual((self.root/'HorizonBase.lua').read_bytes(),b'updated source')
        self.assertEqual((Path(info['backup'])/'LunaHZ.luac').read_bytes(),b'original')
        self.assertEqual((self.root/'config/lunahz.ini').read_bytes(),b'original')
        self.assertFalse((self.root/'LunaHZ.luac').exists())
        deploy.restore(self.root)
        self.assertTrue((self.root/'LunaHZ.luac').exists())
    def test_update_copy_failure_restores_prior_build(self):
        deploy.install(self.root)
        (self.fake_project/'src/HorizonBase.lua').write_bytes(b'updated source')
        real=deploy.shutil.copytree
        def fail(source,destination,*a,**kw):
            if Path(source).as_posix().endswith('build/moonloader/lib/horizonbase'):
                Path(destination).mkdir(parents=True)
                raise OSError('injected update failure')
            return real(source,destination,*a,**kw)
        with patch.object(deploy.shutil,'copytree',side_effect=fail):
            with self.assertRaises(OSError):deploy.update(self.root)
        self.assertEqual((self.root/'HorizonBase.lua').read_bytes(),b'new source')
        self.assertEqual((self.root/'lib/horizonbase/config.lua').read_bytes(),b'new module')
        self.assertFalse((self.root/'LunaHZ.luac').exists())
    def test_new_hud_assets_are_added_without_replacing_old_textures(self):
        deploy.install(self.root)
        hud=self.fake_project/'.local/prepared-hud'/Path(deploy.HUD_ASSETS).name
        hud.mkdir(parents=True);(hud/'hud-font.png').write_bytes(b'font atlas')
        deploy.update(self.root,live=True)
        self.assertEqual((self.root/deploy.HUD_ASSETS/'hud-font.png').read_bytes(),b'font atlas')
        self.assertEqual((self.root/'resource/horizonbase/sa_map/1.jpg').read_bytes(),b'original')
        (hud/'hud-font.png').write_bytes(b'changed atlas')
        with self.assertRaises(ValueError):deploy.update(self.root,live=True)
        self.assertEqual((self.root/deploy.HUD_ASSETS/'hud-font.png').read_bytes(),b'font atlas')

    def test_portrait_bundle_is_added_live_without_changing_prior_artwork(self):
        deploy.install(self.root)
        portraits=self.fake_project/'.local/prepared-hud'/Path(deploy.PORTRAIT_ASSETS).name
        portraits.mkdir(parents=True);(portraits/'292.png').write_bytes(b'portrait')
        deploy.update(self.root,live=True)
        self.assertEqual((self.root/deploy.PORTRAIT_ASSETS/'292.png').read_bytes(),b'portrait')
        self.assertEqual((self.root/'resource/horizonbase/sa_map/1.jpg').read_bytes(),b'original')
        (portraits/'292.png').write_bytes(b'changed portrait')
        with self.assertRaises(ValueError):deploy.update(self.root,live=True)
        self.assertEqual((self.root/deploy.PORTRAIT_ASSETS/'292.png').read_bytes(),b'portrait')

    def test_live_update_replaces_only_lua_sources(self):
        deploy.install(self.root)
        (self.fake_project/'src/HorizonBase.lua').write_bytes(b'updated source')
        with patch.object(deploy,'require_game_closed',side_effect=ValueError('game running')):
            result=deploy.update(self.root,live=True)
        self.assertTrue(result['script_reload_required'])
        self.assertEqual((self.root/'HorizonBase.lua').read_bytes(),b'updated source')
        self.assertEqual((self.root/'resource/horizonbase/sa_map/1.jpg').read_bytes(),b'original')
        self.assertEqual((self.root/'config/lunahz.ini').read_bytes(),b'original')

if __name__=='__main__':unittest.main()
