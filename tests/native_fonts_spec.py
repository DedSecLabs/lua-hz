import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image

TOOLS=Path(__file__).resolve().parents[1]/'tools';sys.path.insert(0,str(TOOLS))
spec=importlib.util.spec_from_file_location('native_fonts',TOOLS/'native_fonts.py')
fonts=importlib.util.module_from_spec(spec);spec.loader.exec_module(fonts)

class NativeFontTests(unittest.TestCase):
    def test_native_texture_structure_and_mip_sizes(self):
        with tempfile.TemporaryDirectory()as tmp:
            root=Path(tmp);pngs=root/'PC Version/PNG Source Files';pngs.mkdir(parents=True)
            for name in ['Bank Gothic and Beckett (1) (Plain).png','Pricedown and TW Century (X) (Plain).png']:
                Image.new('RGBA',(64,64),(255,255,255,255)).save(pngs/name)
            data=fonts.build(root,32);fonts.validate(data,32)
            self.assertIn(b'font1',data);self.assertIn(b'font2',data)
    def test_failed_second_switch_restores_both_fonts(self):
        with tempfile.TemporaryDirectory()as tmp:
            root=Path(tmp);game=root/'GTA San Andreas - SA-MP (LuaHZ)';source=root/'source'
            for relative,data in [('models/fonts.txd',b'original atlas'),('data/fonts.dat',b'original spacing')]:
                p=game/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
            (game/'moonloader/config').mkdir(parents=True)
            dat=source/'PC Version/1 Beckett (Plain)/fonts.dat';dat.parent.mkdir(parents=True);dat.write_bytes(b'new spacing')
            atlas=root/'prepared.txd';atlas.write_bytes(b'new atlas')
            original_replace=fonts.os.replace
            def fail(src,dst):
                if str(dst).endswith('fonts.dat'):raise OSError('injected second-file failure')
                return original_replace(src,dst)
            with patch.object(fonts,'validate'),patch.object(fonts,'require_game_closed'),patch.object(fonts.os,'replace',side_effect=fail):
                with self.assertRaises(OSError):fonts.install(game,source,atlas)
            self.assertEqual((game/'models/fonts.txd').read_bytes(),b'original atlas')
            self.assertEqual((game/'data/fonts.dat').read_bytes(),b'original spacing')
            self.assertFalse((game/'moonloader/config/native-font-deploy.json').exists())
