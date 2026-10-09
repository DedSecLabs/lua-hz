from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import native_loading_bar as bar

class BarTests(unittest.TestCase):
    def setUp(self):
        data=bytearray(bar.WIDTH_CONSTANT_OFFSET+4)
        data[bar.INSTRUCTION_OFFSET:bar.INSTRUCTION_OFFSET+6]=bar.BEFORE
        data[bar.Y_INSTRUCTION_OFFSET:bar.Y_INSTRUCTION_OFFSET+6]=bar.Y_BEFORE
        for offset,value in [(bar.OLD_CONSTANT_OFFSET,50),(bar.CENTER_CONSTANT_OFFSET,230),(bar.WIDTH_CONSTANT_OFFSET,180)]:
            struct.pack_into('<f',data,offset,value)
        struct.pack_into('<f',data,bar.OLD_Y_CONSTANT_OFFSET,40)
        struct.pack_into('<f',data,bar.FOOTER_Y_CONSTANT_OFFSET,25)
        self.original=bytes(data)
        self.hashpatch=patch.object(bar,'ORIGINAL_SHA',bar.sha(self.original));self.hashpatch.start()
        self.closed=patch.object(bar,'require_game_closed');self.closed.start()
        self.temp=tempfile.TemporaryDirectory();self.game=Path(self.temp.name)/'GTA San Andreas - SA-MP (LuaHZ)'
        (self.game/'moonloader/config').mkdir(parents=True);(self.game/'gta_sa.exe').write_bytes(self.original)
    def tearDown(self):self.temp.cleanup();self.closed.stop();self.hashpatch.stop()

    def test_constant_reference_only_and_resolution_independent_center(self):
        result=bar.build(self.original);offset=bar.INSTRUCTION_OFFSET
        self.assertEqual(result[:offset],self.original[:offset])
        self.assertEqual(result[offset+6:],self.original[offset+6:])
        self.assertEqual(result[offset:offset+6],bar.AFTER)
        center=struct.unpack_from('<f',result,bar.CENTER_CONSTANT_OFFSET)[0]
        width=struct.unpack_from('<f',result,bar.WIDTH_CONSTANT_OFFSET)[0]
        for screen in [640,1024,1280,1920,2560,3840]:
            x=screen*center/640;w=screen*width/640
            self.assertEqual(x+w/2,screen/2)
        with self.assertRaises(ValueError):bar.build(result)

    def test_install_restore_and_external_change_guard(self):
        info=bar.install(self.game);target=self.game/'gta_sa.exe';installed=target.read_bytes()
        self.assertTrue(info['other_executable_bytes_unchanged'])
        with self.assertRaises(ValueError):bar.install(self.game)
        target.write_bytes(installed+b'changed')
        with self.assertRaises(ValueError):bar.restore(self.game)
        target.write_bytes(installed);bar.restore(self.game)
        self.assertEqual(target.read_bytes(),self.original)

    def test_receipt_failure_restores_executable(self):
        real=bar.write_atomic
        def failing(path,data):
            if path.name=='loading-bar-deploy.json':raise OSError('receipt failure')
            real(path,data)
        with patch.object(bar,'write_atomic',side_effect=failing):
            with self.assertRaises(OSError):bar.install(self.game)
        self.assertEqual((self.game/'gta_sa.exe').read_bytes(),self.original)
        self.assertFalse((self.game/'moonloader/config/loading-bar-deploy.json').exists())

    def test_footer_alignment_scales_with_resolution_and_preserves_dimensions(self):
        result=bar.build(self.original,footer=True)
        normalized=bytearray(result)
        for offset in [bar.INSTRUCTION_OFFSET,bar.Y_INSTRUCTION_OFFSET]:
            normalized[offset:offset+6]=self.original[offset:offset+6]
        self.assertEqual(bytes(normalized),self.original)
        for width,height in [(1280,720),(1920,1080),(2560,1440),(3840,2160)]:
            x=width*230/640;w=width*180/640;y=height-height*25/448;h=int(height*10/448)
            self.assertEqual(x+w/2,width/2)
            # Credits center near 95.5% height; bar center follows it to within
            # one pixel at all tested sizes, beneath the mosaic ending at 91%.
            self.assertLess(abs(y+h/2-height*.955),1)
            self.assertGreater(y,height*.91)

    def test_footer_update_receipt_failure_recovers_previous_position(self):
        first=bar.install(self.game);target=self.game/'gta_sa.exe';before=target.read_bytes()
        receipt=self.game/'moonloader/config/loading-bar-deploy.json';previous=receipt.read_bytes()
        real=bar.write_atomic;failed=False
        def failing(path,data):
            nonlocal failed
            if path==receipt and not failed:
                failed=True;raise OSError('simulated footer receipt failure')
            real(path,data)
        with patch.object(bar,'write_atomic',side_effect=failing):
            with self.assertRaises(OSError):bar.update(self.game)
        self.assertEqual(target.read_bytes(),before);self.assertEqual(receipt.read_bytes(),previous)
        info=bar.update(self.game);self.assertEqual(info['backup'],first['backup'])
        self.assertEqual(target.read_bytes(),bar.build(self.original,footer=True))
        bar.restore(self.game);self.assertEqual(target.read_bytes(),self.original)

if __name__=='__main__':unittest.main()
