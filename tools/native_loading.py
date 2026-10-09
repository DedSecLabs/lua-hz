#!/usr/bin/env python3
"""Legacy filename redirect, retained for recovery and historical tests.

SAMPFUNCS RenderSplash bypasses this dictionary. Use sampfuncs_loading.py for
the current clean copy; this approach was removed from the game in 0.2.26.

SA-MP serves loadscs.txd from its SAA archive. A distinct, equal-length filename
lets GTA read our separate dictionary without adding a file-hook plugin or
altering SA-MP archives, gameplay resources or executable instruction bytes.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import struct
from PIL import Image
from deploy import require_game_closed
from native_fonts import texture
from native_radar import txd_parts

OLD=b'loadscs.txd\0'
NEW=b'luahzls.txd\0'
ART_NAMES={f'loadsc{i}' for i in range(15)}|{'nvidia'}

def sha(data):return hashlib.sha256(data).hexdigest()

def redirect(exe):
    if not exe.startswith(b'MZ') or len(exe)<256:raise ValueError('Not a PE executable')
    pe=struct.unpack_from('<I',exe,0x3C)[0]
    if exe[pe:pe+4]!=b'PE\0\0':raise ValueError('Invalid PE header')
    machine,sections=struct.unpack_from('<HH',exe,pe+4)
    if machine!=0x14C:raise ValueError('Expected the 32-bit GTA executable')
    optional=struct.unpack_from('<H',exe,pe+20)[0]
    if exe.count(OLD)!=1 or NEW in exe:raise ValueError('Expected one original loading filename')
    offset=exe.index(OLD);in_data=False
    for i in range(sections):
        pos=pe+24+optional+i*40
        name=exe[pos:pos+8].split(b'\0')[0]
        size,start=struct.unpack_from('<II',exe,pos+16)
        flags=struct.unpack_from('<I',exe,pos+36)[0]
        if start<=offset and offset+len(OLD)<=start+size:
            in_data=name==b'.rdata' and not flags&0x20000000
    if not in_data:raise ValueError('Loading filename is not in the expected read-only data section')
    result=exe[:offset]+NEW+exe[offset+len(OLD):]
    assert len(result)==len(exe) and result[:offset]==exe[:offset] and result[offset+len(OLD):]==exe[offset+len(OLD):]
    return result,offset

def build(original,artwork,size=(1024,512)):
    parts=txd_parts(original)
    names={name for _,name,_ in parts if name}
    if not ART_NAMES<=names:raise ValueError('Loading dictionary is missing expected sprites')
    # Format/size conversion for the native texture encoder, not a creative edit.
    with Image.open(artwork) as im:image=im.convert('RGBA').resize(size,Image.Resampling.LANCZOS)
    body=b''.join(texture(name,image) if name in ART_NAMES else data for _,name,data in parts)
    result=struct.pack('<III',22,len(body),struct.unpack_from('<I',original,8)[0])+body
    after=txd_parts(result)
    if [(k,n)for k,n,_ in after]!=[(k,n)for k,n,_ in parts]:raise ValueError('Texture names/order changed')
    if [p for p in parts if p[1]not in ART_NAMES]!=[p for p in after if p[1]not in ART_NAMES]:
        raise ValueError('Copyright/EAX or unrelated textures changed')
    for _,name,data in after:
        if name in ART_NAMES:
            _,fmt,w,h,depth,levels,_,_=struct.unpack_from('<IIHHBBBB',data,96)
            if (fmt,w,h,depth)!=(21,*size,32) or levels<2:raise ValueError('Invalid loading raster')
    return result

def write_atomic(target,data):
    temp=target.with_name(target.name+'.luahz-loading.tmp')
    created=False
    try:
        with temp.open('xb') as f:
            created=True;f.write(data);f.flush();os.fsync(f.fileno())
        os.replace(temp,target)
    finally:
        if created and temp.exists():temp.unlink()

def install(game,artwork):
    require_game_closed()
    if game.name!='GTA San Andreas - SA-MP (LuaHZ)':raise ValueError('Use the independent LuaHZ clone')
    receipt=game/'moonloader/config/native-loading-deploy.json'
    if receipt.exists():raise ValueError('Loading artwork already installed; restore before installing another version')
    target=game/'models/txd/luahzls.txd';exe=game/'gta_sa.exe'
    if target.exists():raise ValueError('A custom loading dictionary already exists')
    original=exe.read_bytes();patched,offset=redirect(original)
    dictionary=build((game/'models/txd/LOADSCS.txd').read_bytes(),artwork)
    stamp=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup=game/'Loading screen backups'/stamp;backup.mkdir(parents=True)
    (backup/'gta_sa.exe').write_bytes(original)
    info={'backup':str(backup),'artwork':str(artwork),'artwork_sha256':sha(artwork.read_bytes()),
          'original_exe_sha256':sha(original),'installed_exe_sha256':sha(patched),
          'dictionary_sha256':sha(dictionary),'filename_offset':offset,'data_only_filename_change':True,
          'original_loading_dictionary_preserved':True,'archive_and_plugins_preserved':True,
          'native_texture_size':[1024,512],'replaced_sprites':sorted(ART_NAMES),
          'activation':'Next full game launch; in-game QA by the user'}
    written=False
    try:
        require_game_closed()
        if exe.read_bytes()!=original:raise ValueError('Game executable changed during preparation')
        write_atomic(target,dictionary)
        written=True;write_atomic(exe,patched)
        if exe.read_bytes()!=patched or target.read_bytes()!=dictionary:raise ValueError('Loading installation verification failed')
        receipt.write_text(json.dumps(info,indent=2)+'\n')
        (backup/'deployment.json').write_bytes(receipt.read_bytes())
    except Exception:
        if written:write_atomic(exe,original)
        if target.exists():target.unlink()
        if receipt.exists():receipt.unlink()
        raise
    return info

def update(game,artwork):
    require_game_closed()
    if game.name!='GTA San Andreas - SA-MP (LuaHZ)':raise ValueError('Use the independent LuaHZ clone')
    receipt=game/'moonloader/config/native-loading-deploy.json'
    previous=receipt.read_bytes();info=json.loads(previous)
    target=game/'models/txd/luahzls.txd';before=target.read_bytes()
    if sha((game/'gta_sa.exe').read_bytes())!=info['installed_exe_sha256'] or sha(before)!=info['dictionary_sha256']:
        raise ValueError('Loading installation changed; review before updating')
    result=build(before,artwork)
    stamp=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup=game/'Loading screen backups'/'updates'/stamp;backup.mkdir(parents=True)
    (backup/'luahzls.txd').write_bytes(before);(backup/'previous-deployment.json').write_bytes(previous)
    switched=False
    try:
        require_game_closed()
        if target.read_bytes()!=before:raise ValueError('Loading dictionary changed during preparation')
        write_atomic(target,result)
        switched=True
        if target.read_bytes()!=result:raise ValueError('Loading artwork update verification failed')
        info.update(artwork=str(artwork),artwork_sha256=sha(artwork.read_bytes()),dictionary_sha256=sha(result),
                    last_update_backup=str(backup))
        receipt.write_text(json.dumps(info,indent=2)+'\n')
        (backup/'deployment.json').write_bytes(receipt.read_bytes())
    except Exception:
        if switched:write_atomic(target,before)
        receipt.write_bytes(previous)
        raise
    return info

def restore(game):
    require_game_closed()
    receipt=game/'moonloader/config/native-loading-deploy.json';info=json.loads(receipt.read_text())
    backup=Path(info['backup'])
    if backup.resolve().parent!=(game/'Loading screen backups').resolve():raise ValueError('Unexpected backup path')
    exe=game/'gta_sa.exe';target=game/'models/txd/luahzls.txd';original=(backup/'gta_sa.exe').read_bytes()
    if sha(original)!=info['original_exe_sha256'] or sha(exe.read_bytes())!=info['installed_exe_sha256']:
        raise ValueError('Executable changed since installation; restore requires review')
    if sha(target.read_bytes())!=info['dictionary_sha256']:raise ValueError('Loading dictionary changed since installation')
    write_atomic(exe,original);target.unlink();receipt.rename(backup/'restored-deployment.json')
    return {'restored':str(game),'backup':str(backup)}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['install','update','restore']);parser.add_argument('--game',required=True,type=Path)
    parser.add_argument('--artwork',type=Path);args=parser.parse_args()
    if args.action!='restore' and args.artwork is None:parser.error('--artwork is required for install/update')
    result=restore(args.game.resolve()) if args.action=='restore' else globals()[args.action](args.game.resolve(),args.artwork.resolve())
    print(json.dumps(result,indent=2))
