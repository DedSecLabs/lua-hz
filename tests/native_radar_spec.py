import importlib.util
from pathlib import Path
import struct
import sys
import tempfile
import unittest

TOOLS=Path(__file__).resolve().parents[1]/'tools'
sys.path.insert(0,str(TOOLS))
spec=importlib.util.spec_from_file_location('native_radar',TOOLS/'native_radar.py')
radar=importlib.util.module_from_spec(spec);spec.loader.exec_module(radar)

class NativeRadarTests(unittest.TestCase):
    def test_append_only_replacement_preserves_other_content_and_source(self):
        with tempfile.TemporaryDirectory()as tmp:
            p=Path(tmp)/'original.img';out=Path(tmp)/'prepared.img'
            header=b'VER2'+struct.pack('<I',2)
            entries=struct.pack('<IHH24s',1,1,0,b'radar00.txd')+struct.pack('<IHH24s',2,1,0,b'unrelated.txd')
            original=(header+entries).ljust(2048,b'\0')+b'old radar'.ljust(2048,b'\0')+b'other data'.ljust(2048,b'\0')
            p.write_bytes(original)
            replacement=b'new HD texture'*250
            info=radar.stage(p,out,{'radar00.txd':replacement})
            self.assertTrue(info['all_original_payload_bytes_preserved'])
            self.assertEqual(p.read_bytes(),original)
            raw,parsed=radar.directory(out)
            self.assertEqual(parsed[1],('unrelated.txd',2,1,0))
            result=out.read_bytes()
            self.assertEqual(result[2048:6144],original[2048:6144])
            self.assertEqual(result[parsed[0][1]*2048:][:len(replacement)],replacement)
            self.assertGreater(parsed[0][2],1)
    def test_missing_duplicate_and_malformed_archives_are_rejected(self):
        with tempfile.TemporaryDirectory()as tmp:
            p=Path(tmp)/'bad.img';out=Path(tmp)/'prepared.img'
            p.write_bytes(b'bad file')
            with self.assertRaises((ValueError,struct.error)):radar.stage(p,out,{'radar00.txd':b'HD'})
            self.assertFalse(out.exists())
            record=struct.pack('<IHH24s',1,1,0,b'radar00.txd')
            p.write_bytes((b'VER2'+struct.pack('<I',2)+record+record).ljust(2048,b'\0')+bytes(2048))
            with self.assertRaises(ValueError):radar.stage(p,out,{'radar00.txd':b'HD'})
            self.assertFalse(out.exists())
    def test_overview_replaces_only_map_and_keeps_menu_backgrounds(self):
        def chunk(kind,payload):return struct.pack('<III',kind,len(payload),0x1803FFFF)+payload
        def texture(name,payload):
            header=bytearray(88);struct.pack_into('<I',header,0,9);header[8:8+len(name)]=name.encode()
            return chunk(21,chunk(1,bytes(header)+payload))
        def package(background,mapdata):
            return chunk(22,chunk(1,struct.pack('<HH',2,2))+texture('back2',background)+texture('map',mapdata)+chunk(3,b''))
        old=package(b'original background',b'old map')
        source=package(b'unwanted different background',b'new HD map'*100)
        result=radar.replace_overview(old,source)
        parts=radar.txd_parts(result)
        self.assertIn(b'new HD map',next(p[2]for p in parts if p[1]=='map'))
        self.assertEqual(next(p[2]for p in parts if p[1]=='back2'),next(p[2]for p in radar.txd_parts(old)if p[1]=='back2'))
        self.assertNotIn(b'unwanted different background',result)

    def test_existing_staging_file_is_never_overwritten(self):
        with tempfile.TemporaryDirectory()as tmp:
            p=Path(tmp)/'original.img';out=Path(tmp)/'prepared.img'
            p.write_bytes((b'VER2'+struct.pack('<I',1)+struct.pack('<IHH24s',1,1,0,b'radar00.txd')).ljust(2048,b'\0')+bytes(2048))
            out.write_bytes(b'keep me')
            with self.assertRaises(FileExistsError):radar.stage(p,out,{'radar00.txd':b'HD'})
            self.assertEqual(out.read_bytes(),b'keep me')
