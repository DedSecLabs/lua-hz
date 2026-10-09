from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import sampfuncs_loading as loading
from native_fonts import chunk

def fixture():
    native=struct.pack('<I2BH32s32s',9,1,0x11,0,b'_'.ljust(32,b'\0'),bytes(32))
    native+=struct.pack('<IIHHBBBB',512,0x31545844,1024,1024,16,1,4,8)
    native+=struct.pack('<I',loading.PIXELS)+bytes(loading.PIXELS)
    txd=chunk(22,chunk(1,struct.pack('<HH',1,2))+chunk(21,chunk(1,native)+chunk(3,b''))+chunk(3,b''))
    data=bytearray(1671168);key=bytes(range(32))
    data[:2]=b'MZ';struct.pack_into('<I',data,0x3c,0x80)
    data[0x80:0x84]=b'PE\0\0'
    struct.pack_into('<H',data,0x86,6);struct.pack_into('<H',data,0x94,0xe0)
    struct.pack_into('<H',data,0x98,0x10b)
    struct.pack_into('<I',data,0x98+8,0x10ea00)
    struct.pack_into('<II',data,0x98+32,0x1000,0x200)
    struct.pack_into('<II',data,0x98+56,0x1d4000,0x400)
    struct.pack_into('<II',data,loading.RESOURCE_LEAF,0x1410a0,loading.LENGTH)
    data[loading.KEY_OFFSET:loading.KEY_OFFSET+32]=key
    data[loading.FIT_OFFSET:loading.FIT_OFFSET+2]=loading.FIT_BEFORE
    data[loading.OFFSET:loading.OFFSET+loading.LENGTH]=loading.encode(txd,key)
    return bytes(data),txd,key

class SplashTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();base=Path(self.temp.name)
        self.game=base/'GTA San Andreas - SA-MP (LuaHZ)'
        (self.game/'moonloader/config').mkdir(parents=True)
        self.original,self.txd,self.key=fixture()
        (self.game/'SAMPFUNCS.asi').write_bytes(self.original)
        self.art=base/'art.png';Image.new('RGB',(64,36),(240,128,32)).save(self.art)
        self.hashpatch=patch.object(loading,'ORIGINAL_SHA',loading.sha(self.original));self.hashpatch.start()
        self.closed=patch.object(loading,'require_game_closed');self.closed.start()
    def tearDown(self):self.closed.stop();self.hashpatch.stop();self.temp.cleanup()

    def test_native_headers_and_all_other_plugin_bytes_preserved(self):
        after=loading.build(self.original,self.art)
        self.assertEqual(after[:loading.FIT_OFFSET],self.original[:loading.FIT_OFFSET])
        self.assertEqual(after[loading.FIT_OFFSET+1:loading.OFFSET],self.original[loading.FIT_OFFSET+1:loading.OFFSET])
        self.assertEqual(after[loading.FIT_OFFSET:loading.FIT_OFFSET+2],loading.FIT_AFTER)
        # Both jumps target the same instruction after the complete override;
        # no pushes, pops or calls inside that override execute on this path.
        self.assertEqual(0x1b99c+2+after[loading.FIT_OFFSET+1],0x1b9f3)
        self.assertEqual(after[loading.OFFSET+loading.LENGTH:],self.original[loading.OFFSET+loading.LENGTH:])
        decoded=loading.decode(after[loading.OFFSET:loading.OFFSET+loading.LENGTH],self.key)
        start=loading.raster(decoded)
        self.assertEqual(decoded[:start],self.txd[:start])
        self.assertEqual(decoded[start+loading.PIXELS:],self.txd[start+loading.PIXELS:])
        self.assertNotEqual(decoded[start:start+loading.PIXELS],self.txd[start:start+loading.PIXELS])
        self.assertEqual(loading.decode(loading.encode(decoded,self.key),self.key),decoded)
        with self.assertRaises(ValueError):loading.build(after,self.art)
        with self.assertRaises(ValueError):loading.raster(b'bad dictionary')

    def test_install_restore_and_changed_file_guard(self):
        info=loading.install(self.game,self.art)
        self.assertTrue(info['all_bytes_outside_image_and_fit_patch_unchanged'])
        target=self.game/'SAMPFUNCS.asi';installed=target.read_bytes()
        with self.assertRaises(ValueError):loading.install(self.game,self.art)
        target.write_bytes(installed+b'changed')
        with self.assertRaises(ValueError):loading.restore(self.game)
        target.write_bytes(installed);loading.restore(self.game)
        self.assertEqual(target.read_bytes(),self.original)
        self.assertFalse((self.game/'moonloader/config/sampfuncs-loading-deploy.json').exists())

    def test_update_preserves_original_backup_and_rolls_back_receipt_failure(self):
        info=loading.install(self.game,self.art)
        target=self.game/'SAMPFUNCS.asi';before=target.read_bytes()
        receipt=self.game/'moonloader/config/sampfuncs-loading-deploy.json';previous=receipt.read_bytes()
        Image.new('RGB',(64,36),(32,128,240)).save(self.art)
        real=loading.write_atomic;failed=False
        def failing(path,data):
            nonlocal failed
            if path==receipt and not failed:
                failed=True;raise OSError('simulated update receipt failure')
            real(path,data)
        with patch.object(loading,'write_atomic',side_effect=failing):
            with self.assertRaises(OSError):loading.update(self.game,self.art)
        self.assertEqual(target.read_bytes(),before);self.assertEqual(receipt.read_bytes(),previous)
        updated=loading.update(self.game,self.art)
        self.assertEqual(updated['backup'],info['backup'])
        self.assertEqual((Path(info['backup'])/'SAMPFUNCS.asi').read_bytes(),self.original)
        self.assertNotEqual(target.read_bytes(),before)
        loading.restore(self.game);self.assertEqual(target.read_bytes(),self.original)

    def test_receipt_failure_restores_plugin(self):
        real=loading.write_atomic
        def failing(target,data):
            if target.name=='sampfuncs-loading-deploy.json':raise OSError('simulated receipt failure')
            real(target,data)
        with patch.object(loading,'write_atomic',side_effect=failing):
            with self.assertRaises(OSError):loading.install(self.game,self.art)
        self.assertEqual((self.game/'SAMPFUNCS.asi').read_bytes(),self.original)
        self.assertFalse((self.game/'moonloader/config/sampfuncs-loading-deploy.json').exists())

    def test_lossless_resource_retains_color_and_original_section_bytes(self):
        # A detailed colored fixture exercises RGB ordering and prevents a
        # compressed/blank payload from passing as the lossless path.
        art=Image.new('RGB',(64,36))
        art.putdata([(x*4,y*7,(x*13+y*19)%256) for y in range(36) for x in range(64)])
        art.save(self.art)
        after=loading.build_lossless(self.original,self.art)
        metadata,txd=loading.hd_resource(after)
        self.assertEqual(metadata['texture']['format'],'A8R8G8B8')
        self.assertEqual(metadata['offset'],len(self.original))
        pixels=txd[144:-24]
        expected=art.convert('RGBA').resize((loading.HD_WIDTH,loading.HD_HEIGHT),Image.Resampling.LANCZOS)
        self.assertEqual(pixels,expected.tobytes('raw','BGRA'))
        # Normalizing only permitted PE metadata and the fit opcode recovers
        # the entire original binary, including the old resource and imports.
        normalized=bytearray(after[:len(self.original)])
        for offset,size in [(0x86,2),(0xa0,4),(0xd0,4),(0x268,40),
                            (loading.RESOURCE_LEAF,8),(loading.FIT_OFFSET,2)]:
            normalized[offset:offset+size]=self.original[offset:offset+size]
        self.assertEqual(bytes(normalized),self.original)
        damaged=bytearray(self.original);damaged[0x268]=1
        with patch.object(loading,'ORIGINAL_SHA',loading.sha(damaged)):
            with self.assertRaises(ValueError):loading.build_lossless(bytes(damaged),self.art)

    def test_hd_update_restores_previous_plugin_on_failure_and_preserves_original_recovery(self):
        original_info=loading.install(self.game,self.art)
        target=self.game/'SAMPFUNCS.asi';before=target.read_bytes()
        receipt=self.game/'moonloader/config/sampfuncs-loading-deploy.json';previous=receipt.read_bytes()
        real=loading.write_atomic;failed=False
        def failing(path,data):
            nonlocal failed
            if path==receipt and not failed:
                failed=True;raise OSError('simulated HD receipt failure')
            real(path,data)
        with patch.object(loading,'write_atomic',side_effect=failing):
            with self.assertRaises(OSError):loading.update(self.game,self.art,lossless=True)
        self.assertEqual(target.read_bytes(),before);self.assertEqual(receipt.read_bytes(),previous)
        info=loading.update(self.game,self.art,lossless=True)
        self.assertEqual(info['backup'],original_info['backup'])
        self.assertEqual(info['resource']['section'],'.hzhd')
        loading.hd_resource(target.read_bytes())
        Image.new('RGB',(64,36),(50,100,150)).save(self.art)
        next_info=loading.update(self.game,self.art)
        self.assertEqual(next_info['texture']['format'],'A8R8G8B8')
        loading.hd_resource(target.read_bytes())
        loading.restore(self.game);self.assertEqual(target.read_bytes(),self.original)

if __name__=='__main__':unittest.main()
