#!/usr/bin/env python3
"""Back up and upgrade only the clean LuaHZ copy's native radar IMG entries.

Append-only staging preserves every original payload byte and every unrelated
directory record. Native game processes must be closed for the final switch.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
from deploy import require_game_closed

SECTOR=2048
def txd_parts(data):
    if len(data)<12 or struct.unpack_from('<II',data)!=(22,len(data)-12):raise ValueError('Malformed TXD')
    result=[];pos=12
    while pos<len(data):
        if pos+12>len(data):raise ValueError('Truncated TXD chunk')
        kind,size,version=struct.unpack_from('<III',data,pos);end=pos+12+size
        if end>len(data):raise ValueError('TXD chunk exceeds file')
        name=None
        if kind==21:
            if size<100 or struct.unpack_from('<I',data,pos+12)[0]!=1:raise ValueError('Unsupported native texture')
            name=data[pos+32:pos+64].split(b'\0')[0].decode('ascii')
        result.append((kind,name,data[pos:end]));pos=end
    return result

def replace_overview(original,source):
    old=txd_parts(original);new=txd_parts(source)
    maps=[part[2]for part in new if part[1]=='map']
    if len(maps)!=1 or sum(part[1]=='map'for part in old)!=1:raise ValueError('Missing/duplicate overview map')
    body=b''.join(maps[0]if name=='map'else data for kind,name,data in old)
    result=struct.pack('<III',22,len(body),struct.unpack_from('<I',original,8)[0])+body
    verified=txd_parts(result)
    if [p for p in old if p[1]!='map']!=[p for p in verified if p[1]!='map']:
        raise ValueError('Unrelated frontend textures changed')
    return result

def upgrade_overview(game,source,receipt):
    info=json.loads(receipt.read_text());before_receipt=receipt.read_bytes()
    if info.get('overview'):raise ValueError('Overview already upgraded')
    original=game/'models/fronten2.txd';before=original.read_bytes()
    result=replace_overview(before,source.read_bytes())
    backup=Path(info['backup']).parent/'fronten2.txd'
    if backup.exists():raise ValueError('Overview backup already exists')
    output=original.with_name('fronten2.txd.luahz-map.tmp')
    with output.open('xb')as f:f.write(result);f.flush();os.fsync(f.fileno())
    moved=switched=False
    try:
        require_game_closed()
        if original.read_bytes()!=before:raise ValueError('Frontend changed while staging')
        original.rename(backup);moved=True;output.rename(original);switched=True
        if original.read_bytes()!=result:raise ValueError('Overview verification failed')
        info['overview']={'backup':str(backup),'source':str(source),'texture':'map',
                          'original_sha256':hashlib.sha256(before).hexdigest(),
                          'new_sha256':hashlib.sha256(result).hexdigest(),
                          'all_other_frontend_textures_unchanged':True}
        receipt.write_text(json.dumps(info,indent=2)+'\n')
        (backup.parent/'deployment.json').write_bytes(receipt.read_bytes())
    except Exception:
        if switched:original.unlink()
        if moved:backup.rename(original)
        if output.exists():output.unlink()
        receipt.write_bytes(before_receipt)
        raise
    return info['overview']
def directory(path):
    size=path.stat().st_size
    with path.open('rb')as f:
        magic,count=struct.unpack('<4sI',f.read(8))
        if magic!=b'VER2' or count>100000 or 8+count*32>size or size%SECTOR:
            raise ValueError('Unsupported or malformed IMG archive')
        raw=f.read(count*32)
    entries=[]
    for i in range(count):
        offset,length,archive,name=struct.unpack_from('<IHH24s',raw,i*32)
        name=name.split(b'\0')[0].decode('ascii')
        if not name or (offset+length)*SECTOR>size:raise ValueError('Invalid IMG entry')
        entries.append((name,offset,length,archive))
    return raw,entries

def stage(original,output,replacements):
    raw,entries=directory(original)
    names=[e[0].lower()for e in entries]
    for name in replacements:
        if names.count(name.lower())!=1:raise ValueError('Missing/duplicate IMG target: '+name)
    before=original.stat();digest=hashlib.sha256()
    # Exclusive creation prevents overwriting someone else's interrupted output.
    with original.open('rb')as src,output.open('xb')as dst:
        while data:=src.read(4*1024*1024):digest.update(data);dst.write(data)
        updated=bytearray(raw);changed=[]
        for i,(name,offset,length,archive)in enumerate(entries):
            if name.lower()not in replacements:continue
            data=replacements[name.lower()]
            if archive!=0 or not data:raise ValueError('Unsupported compressed/empty target')
            offset=dst.tell()//SECTOR;length=(len(data)+SECTOR-1)//SECTOR
            if length>65535:raise ValueError('Texture exceeds IMG entry size')
            dst.write(data);dst.write(b'\0'*(length*SECTOR-len(data)))
            struct.pack_into('<IHH',updated,i*32,offset,length,archive)
            changed.append({'name':name,'offset':offset,'sectors':length,'bytes':len(data),
                            'sha256':hashlib.sha256(data).hexdigest()})
        dst.seek(8);dst.write(updated);dst.flush();os.fsync(dst.fileno())
    # Normalize the changed directory to verify the entire original file region.
    check=hashlib.sha256();remaining=before.st_size
    with output.open('rb')as f:
        first=bytearray(f.read(min(4*1024*1024,remaining)))
        first[8:8+len(raw)]=raw;check.update(first);remaining-=len(first)
        while remaining:
            block=f.read(min(4*1024*1024,remaining))
            if not block:raise ValueError('Truncated staged archive')
            check.update(block);remaining-=len(block)
    if check.digest()!=digest.digest():raise ValueError('Original archive bytes were not preserved')
    _,new_entries=directory(output)
    with output.open('rb')as f:
        for i,(name,offset,length,archive)in enumerate(new_entries):
            if name.lower()not in replacements:
                if new_entries[i]!=entries[i]:raise ValueError('Unrelated directory entry changed')
            else:
                expected=replacements[name.lower()];f.seek(offset*SECTOR)
                if f.read(len(expected))!=expected:raise ValueError('Replacement verification failed')
    if original.stat().st_mtime_ns!=before.st_mtime_ns or original.stat().st_size!=before.st_size:
        raise ValueError('Original changed while staging')
    return {'original_sha256':digest.hexdigest(),'original_bytes':before.st_size,'new_bytes':output.stat().st_size,
            'replaced_entries':changed,'all_original_payload_bytes_preserved':True}

def validate_texture(name,data):
    if len(data)<140 or struct.unpack_from('<II',data)!=(22,len(data)-12):raise ValueError('Invalid TXD: '+name)
    # Native D3D9 tile: dictionary header + native/struct headers + 88-byte header.
    if struct.unpack_from('<HH',data,24)[0]!=1 or struct.unpack_from('<I',data,52)[0]!=9:
        raise ValueError('Unexpected texture dictionary: '+name)
    texture_name=data[60:92].split(b'\0')[0].decode('ascii')
    width,height=struct.unpack_from('<HH',data,132)
    if texture_name.lower()!=Path(name).stem.lower() or (width,height)!=(512,512):
        raise ValueError('Wrong radar texture name/resolution: '+name)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',required=True,type=Path)
    parser.add_argument('--textures',required=True,type=Path)
    parser.add_argument('--overview-only',action='store_true')
    args=parser.parse_args();game=args.game.resolve()
    if game.name!='GTA San Andreas - SA-MP (LuaHZ)':raise ValueError('Use the independent LuaHZ clone')
    install=json.loads((game/'moonloader/config/horizonbase-deploy.json').read_text())
    if Path(install['target']).resolve()!=game/'moonloader':raise ValueError('Wrong deployment target')
    require_game_closed()
    receipt=game/'moonloader/config/native-radar-deploy.json'
    if args.overview_only:
        print(json.dumps(upgrade_overview(game,args.textures/'models/fronten2.txd',receipt),indent=2));return
    if receipt.exists():raise ValueError('Native radar already has a deployment receipt; review before updating')
    replacements={}
    for i in range(144):
        name=f'radar{i:02}.txd';data=(args.textures/name).read_bytes()
        validate_texture(name,data);replacements[name]=data
    original=game/'models/gta3.img'
    stamp=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    output=original.with_name('gta3.img.luahz-radar-'+stamp+'.tmp')
    backup=game/'Native radar backups'/stamp;backup.mkdir(parents=True)
    moved=False;switched=False
    try:
        info=stage(original,output,replacements)
        require_game_closed()
        original.rename(backup/'gta3.img');moved=True
        output.rename(original);switched=True
        info.update(backup=str(backup/'gta3.img'),target=str(original),source=str(args.textures.resolve()),
                    asset='Proper Radar v1.3 PC 512',scope='144 radar tiles; ESC map and minimap',
                    no_added_plugins=True,activation='Next game launch')
        receipt.write_text(json.dumps(info,indent=2)+'\n')
        (backup/'deployment.json').write_bytes(receipt.read_bytes())
    except Exception:
        if switched:original.unlink()
        if moved:(backup/'gta3.img').rename(original)
        if output.exists():output.unlink()
        if receipt.exists():receipt.unlink()
        raise
    print(json.dumps({k:v for k,v in info.items()if k!='replaced_entries'},indent=2))
    print('Verified all 144 replacement textures and preserved every original payload byte.')

if __name__=='__main__':main()
