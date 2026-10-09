import importlib.util
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image

TOOLS=Path(__file__).resolve().parents[1]/'tools'
sys.path.insert(0,str(TOOLS))
import native_icons as icons
from native_fonts import chunk,texture
from native_radar import txd_parts

class NativeIconTests(unittest.TestCase):
    def test_pixels_alpha_names_and_unrelated_textures_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            assets=Path(directory)
            image=Image.new('RGBA',(64,61),(20,40,60,128));image.save(assets/'Jizzy.png')
            image.save(assets/'radar_centre.png')
            source=chunk(22,chunk(1,struct.pack('<HH',3,2))+
                texture('radar_LocoSyndicate',Image.new('RGBA',(16,16)))+
                texture('radar_centre',Image.new('RGBA',(16,16)))+
                texture('fist',Image.new('RGBA',(64,64),(255,0,0,255)))+chunk(3,b''))
            result,changes=icons.build(source,assets)
            old=txd_parts(source);new=txd_parts(result)
            self.assertEqual(list(changes),['radar_LocoSyndicate','radar_centre'])
            self.assertEqual(old[3],new[3])
            for kind,name,data in new:
                if name not in changes:continue
                self.assertEqual(struct.unpack_from('<IIHHBBBB',data,96),(0x8500,21,64,64,32,7,4,1))
                pixels=data[116:116+64*64*4]
                self.assertEqual(pixels[:64*4],bytes(64*4))
                self.assertEqual(pixels[64*4:64*4+4],bytes([60,40,20,128]))

    def test_failed_receipt_restores_native_hud(self):
        with tempfile.TemporaryDirectory() as directory:
            game=Path(directory)/'GTA San Andreas - SA-MP (LuaHZ)'
            (game/'models').mkdir(parents=True);(game/'moonloader/config').mkdir(parents=True)
            target=game/'models/hud.txd';target.write_bytes(b'original')
            with patch.object(icons,'require_game_closed'),patch.object(icons,'build',return_value=(b'new',{str(i):{} for i in range(62)})),patch.object(Path,'write_text',side_effect=OSError('receipt failed')):
                with self.assertRaises(OSError):icons.install(game,Path(directory))
            self.assertEqual(target.read_bytes(),b'original')
            self.assertFalse((game/'moonloader/config/native-icons-deploy.json').exists())
            self.assertFalse((game/'models/hud.txd.luahz-icons.tmp').exists())

if __name__=='__main__':unittest.main()
