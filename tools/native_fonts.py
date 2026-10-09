#!/usr/bin/env python3
"""Prepare/install a backed-up 2K native font set for the independent LuaHZ clone."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import struct
from PIL import Image
from deploy import require_game_closed

VERSION=0x1803FFFF
def chunk(kind,data):return struct.pack('<III',kind,len(data),VERSION)+data
def texture(name,image):
    w,h=image.size;levels=[]
    while True:
        levels.append(image.tobytes('raw','BGRA'))
        if image.size==(1,1):break
        image=image.resize((max(1,image.width//2),max(1,image.height//2)),Image.Resampling.BOX)
    # Native D3D9, linear mip filtering, clamp addressing, RGBA with mip levels.
    native=struct.pack('<I2BH32s32s',9,6,0x11,0,name.encode().ljust(32,b'\0'),bytes(32))
    native+=struct.pack('<IIHHBBBB',0x8500,21,w,h,32,len(levels),4,1)
    native+=b''.join(struct.pack('<I',len(data))+data for data in levels)
    return chunk(21,chunk(1,native)+chunk(3,b''))
def build(source,size=2048):
    pngs=source/'PC Version/PNG Source Files'
    names=[('font2','Bank Gothic and Beckett (1) (Plain).png'),('font1','Pricedown and TW Century (X) (Plain).png')]
    payload=chunk(1,struct.pack('<HH',2,2))
    for name,file in names:
        with Image.open(pngs/file)as im:
            image=im.convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
            payload+=texture(name,image)
    return chunk(22,payload+chunk(3,b''))
def validate(data,size):
    assert struct.unpack_from('<II',data)==(22,len(data)-12)
    pos=28;found=[]
    for _ in range(2):
        kind,length,_=struct.unpack_from('<III',data,pos);assert kind==21
        native=pos+24;name=data[native+8:native+40].split(b'\0')[0].decode()
        raster,fmt,w,h,depth,levels,rtype,flags=struct.unpack_from('<IIHHBBBB',data,native+72)
        assert (fmt,w,h,depth)==(21,size,size,32)
        cursor=native+88
        for level in range(levels):
            count=struct.unpack_from('<I',data,cursor)[0]
            assert count==max(size>>level,1)**2*4;cursor+=4+count
        assert cursor<=pos+12+length;pos+=12+length;found.append(name)
    assert found==['font2','font1']
def install(game,source,prepared):
    require_game_closed()
    if game.name!='GTA San Andreas - SA-MP (LuaHZ)':raise ValueError('Use the independent LuaHZ clone')
    receipt=game/'moonloader/config/native-font-deploy.json'
    if receipt.exists():raise ValueError('Font deployment already exists; review before updating')
    staged={'models/fonts.txd':prepared.read_bytes(),'data/fonts.dat':(source/'PC Version/1 Beckett (Plain)/fonts.dat').read_bytes()}
    validate(staged['models/fonts.txd'],2048)
    stamp=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup=game/'Native font backups'/stamp;backup.mkdir(parents=True)
    originals={relative:(game/relative).read_bytes()for relative in staged}
    written=[];created=[]
    try:
        for relative,data in originals.items():
            p=backup/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
        require_game_closed()
        for relative,data in staged.items():
            target=game/relative
            if target.read_bytes()!=originals[relative]:raise ValueError('Native font changed during preparation')
            temp=target.with_name(target.name+'.luahz-font.tmp')
            with temp.open('xb')as f:
                created.append(temp);f.write(data);f.flush();os.fsync(f.fileno())
            os.replace(temp,target);written.append(relative)
            if target.read_bytes()!=data:raise ValueError('Font verification failed')
        info={'asset':'DJDARKO 2025 v1.0.1 plain fonts, local 2K preparation','source':str(source),
              'backup':str(backup),'texture_size':2048,'bytes':len(staged['models/fonts.txd']),
              'files':{relative:{'original_sha256':hashlib.sha256(originals[relative]).hexdigest(),
                                 'new_sha256':hashlib.sha256(data).hexdigest()}for relative,data in staged.items()},
              'activation':'Next game launch','scope':'Native GTA fonts, including game text and menus; not SA-MP chat font'}
        receipt.write_text(json.dumps(info,indent=2)+'\n');(backup/'deployment.json').write_bytes(receipt.read_bytes())
    except Exception:
        for relative in written:(game/relative).write_bytes(originals[relative])
        for temp in created:
            if temp.exists():temp.unlink()
        if receipt.exists():receipt.unlink()
        raise
    return info
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',required=True,type=Path);parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--game',type=Path);args=parser.parse_args()
    data=build(args.source);validate(data,2048);args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_bytes(data)
    if args.game:print(json.dumps(install(args.game.resolve(),args.source.resolve(),args.output),indent=2))
    else:print('Prepared verified native font TXD:',len(data),'bytes')
