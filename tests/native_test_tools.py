"""Compile standalone policy fixtures, with sanitizers on the Linux path."""
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile

def run_c_fixture(source,fixed_game_addresses=False):
    compiler=json.loads(os.environ.get('LUAHZ_TEST_CC','["gcc"]'))
    if not isinstance(compiler,list) or not compiler or not all(isinstance(a,str) for a in compiler):
        raise ValueError('LUAHZ_TEST_CC must contain a JSON compiler argument list')
    with tempfile.TemporaryDirectory(prefix='luahz-native-test-') as directory:
        target=Path(directory)/('fixture.exe' if os.name=='nt' else 'fixture')
        flags=['-std=c11','-Wall','-Wextra','-Werror']
        if os.name!='nt':flags+=['-fsanitize=address,undefined']
        if fixed_game_addresses:flags+=['-Wl,--image-base,0x400000']
        subprocess.run(compiler+flags+[str(source),'-o',str(target)],check=True)
        if fixed_game_addresses:
            # This generated standalone fixture reserves fake GTA addresses in
            # its unused BSS. No game binary is read or modified.
            data=bytearray(target.read_bytes());optional=struct.unpack_from('<I',data,60)[0]+24
            assert struct.unpack_from('<H',data,optional)[0]==0x10b,'Fixture requires an x86 compiler'
            flags=struct.unpack_from('<H',data,optional+70)[0]
            struct.pack_into('<H',data,optional+70,flags&~0x40)
            target.write_bytes(data)
        return subprocess.run([str(target)],capture_output=True,text=True,check=True).stdout
