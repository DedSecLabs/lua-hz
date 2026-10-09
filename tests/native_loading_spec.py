import importlib.util
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image

PROJECT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PROJECT/'tools'))
import native_loading as loading
from native_fonts import chunk,texture
from native_radar import txd_parts

def executable():
    data=bytearray(1024);data[:2]=b'MZ';struct.pack_into('<I',data,0x3C,0x80)
    data[0x80:0x84]=b'PE\0\0';struct.pack_into('<HH',data,0x84,0x14C,2)
    for i,(name,start,flags) in enumerate([(b'.text',512,0x60000020),(b'.rdata',640,0x40000040)]):
        pos=0x98+i*40;data[pos:pos+8]=name.ljust(8,b'\0')
        struct.pack_into('<II',data,pos+16,128,start);struct.pack_into('<I',data,pos+36,flags)
    data[512:640]=bytes(range(128));data[656:656+len(loading.OLD)]=loading.OLD
    return bytes(data)

def dictionary():
    names=sorted(loading.ART_NAMES)+['eax','title_pc_US','title_pc_EU']
    im=Image.new('RGBA',(16,16),(32,64,128,255))
    return chunk(22,chunk(1,struct.pack('<HH',len(names),2))+b''.join(texture(n,im)for n in names)+chunk(3,b''))

class LoadingTests(unittest.TestCase):
    def test_only_readonly_filename_changes(self):
        before=executable();after,offset=loading.redirect(before)
        self.assertEqual(after[:offset],before[:offset]);self.assertEqual(after[offset+len(loading.OLD):],before[offset+len(loading.OLD):])
        self.assertEqual(after[512:640],before[512:640]);self.assertEqual(len(after),len(before))
        self.assertEqual(after[offset:offset+len(loading.NEW)],loading.NEW)
        for malformed in [b'Not an exe',after,before.replace(loading.OLD,b'otherxx.txd\0'),before+loading.OLD]:
            with self.assertRaises(ValueError):loading.redirect(malformed)
        code=bytearray(before);struct.pack_into('<I',code,0x98+40+36,0x60000040)
        with self.assertRaises(ValueError):loading.redirect(bytes(code))

    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.base=Path(self.temp.name)
        self.game=self.base/'GTA San Andreas - SA-MP (LuaHZ)'
        (self.game/'models/txd').mkdir(parents=True);(self.game/'moonloader/config').mkdir(parents=True)
        self.exe=executable();self.txd=dictionary()
        (self.game/'gta_sa.exe').write_bytes(self.exe);(self.game/'models/txd/LOADSCS.txd').write_bytes(self.txd)
        self.art=self.base/'art.png';Image.new('RGB',(64,36),(255,128,32)).save(self.art)
        self.closed=patch.object(loading,'require_game_closed');self.closed.start()
    def tearDown(self):self.closed.stop();self.temp.cleanup()

    def test_dictionary_preserves_copyright_and_native_order(self):
        result=loading.build(self.txd,self.art,size=(64,32))
        before=txd_parts(self.txd);after=txd_parts(result)
        self.assertEqual([(k,n)for k,n,_ in before],[(k,n)for k,n,_ in after])
        self.assertEqual([p for p in before if p[1]not in loading.ART_NAMES],[p for p in after if p[1]not in loading.ART_NAMES])
        for _,name,data in after:
            if name in loading.ART_NAMES:self.assertEqual(struct.unpack_from('<HH',data,104),(64,32))
        with self.assertRaises(ValueError):loading.build(chunk(22,chunk(1,struct.pack('<HH',0,2))),self.art)

    def small_build(self,*args):return loading.build(*args,size=(64,32))

    def test_install_restore_and_collision_guards(self):
        real=loading.build
        with patch.object(loading,'build',side_effect=lambda *a:real(*a,size=(64,32))):
            info=loading.install(self.game,self.art)
        self.assertTrue(info['data_only_filename_change'])
        self.assertEqual((self.game/'models/txd/LOADSCS.txd').read_bytes(),self.txd)
        with self.assertRaises(ValueError):loading.install(self.game,self.art)
        loading.restore(self.game)
        self.assertEqual((self.game/'gta_sa.exe').read_bytes(),self.exe)
        self.assertFalse((self.game/'models/txd/luahzls.txd').exists())
        (self.game/'models/txd/luahzls.txd').write_bytes(b'other mod')
        with self.assertRaises(ValueError):loading.install(self.game,self.art)

    def test_failed_switch_restores_executable_and_removes_added_texture(self):
        real_build=loading.build;real_write=loading.write_atomic;fail=[True]
        def write(target,data):
            if target.name=='gta_sa.exe' and fail[0]:fail[0]=False;raise OSError('injected switch failure')
            return real_write(target,data)
        with patch.object(loading,'build',side_effect=lambda *a:real_build(*a,size=(64,32))),patch.object(loading,'write_atomic',side_effect=write):
            with self.assertRaises(OSError):loading.install(self.game,self.art)
        self.assertEqual((self.game/'gta_sa.exe').read_bytes(),self.exe)
        self.assertFalse((self.game/'models/txd/luahzls.txd').exists())
        self.assertFalse((self.game/'moonloader/config/native-loading-deploy.json').exists())

    def test_restore_rejects_later_executable_changes(self):
        real=loading.build
        with patch.object(loading,'build',side_effect=lambda *a:real(*a,size=(64,32))):loading.install(self.game,self.art)
        exe=self.game/'gta_sa.exe';exe.write_bytes(exe.read_bytes()+b'other change')
        with self.assertRaises(ValueError):loading.restore(self.game)

    def test_existing_staging_file_is_preserved(self):
        target=self.base/'file';temp=self.base/'file.luahz-loading.tmp';temp.write_bytes(b'previous work')
        with self.assertRaises(FileExistsError):loading.write_atomic(target,b'new payload')
        self.assertEqual(temp.read_bytes(),b'previous work')

    def test_artwork_update_preserves_executable_and_original_restore(self):
        real=loading.build
        with patch.object(loading,'build',side_effect=lambda *a:real(*a,size=(64,32))):
            installed=loading.install(self.game,self.art)
            exe=(self.game/'gta_sa.exe').read_bytes()
            prior=(self.game/'models/txd/luahzls.txd').read_bytes()
            Image.new('RGB',(64,36),(20,40,80)).save(self.art)
            updated=loading.update(self.game,self.art)
        self.assertEqual((self.game/'gta_sa.exe').read_bytes(),exe)
        self.assertEqual(updated['backup'],installed['backup'])
        self.assertEqual((Path(updated['last_update_backup'])/'luahzls.txd').read_bytes(),prior)
        self.assertNotEqual(updated['dictionary_sha256'],installed['dictionary_sha256'])
        loading.restore(self.game);self.assertEqual((self.game/'gta_sa.exe').read_bytes(),self.exe)

    def test_failed_artwork_receipt_restores_previous_dictionary(self):
        real=loading.build;receipt=self.game/'moonloader/config/native-loading-deploy.json'
        original_write=Path.write_text
        with patch.object(loading,'build',side_effect=lambda *a:real(*a,size=(64,32))):
            loading.install(self.game,self.art)
            previous=receipt.read_bytes();target=self.game/'models/txd/luahzls.txd';prior=target.read_bytes()
            Image.new('RGB',(64,36),(20,40,80)).save(self.art)
            def write(path,*args,**kwargs):
                if path==receipt:raise OSError('injected receipt failure')
                return original_write(path,*args,**kwargs)
            with patch.object(Path,'write_text',new=write):
                with self.assertRaises(OSError):loading.update(self.game,self.art)
        self.assertEqual(receipt.read_bytes(),previous);self.assertEqual(target.read_bytes(),prior)

if __name__=='__main__':unittest.main()
