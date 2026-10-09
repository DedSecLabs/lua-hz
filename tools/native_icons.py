#!/usr/bin/env python3
"""Replace native radar sprites with the local Quickmap artwork, with rollback."""
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

ALIASES={'radar_locosyndicate':'Jizzy', 'radar_hostpital':'radar_hostpital'}

def build(original, assets):
    parts=txd_parts(original)
    files={p.stem.lower():p for p in assets.glob('*.png')}
    changes={};body=[]
    for kind,name,data in parts:
        key=ALIASES.get(name.lower(),name).lower() if name else ''
        source=files.get(key) if name and (name.lower().startswith('radar_') or name=='arrow') else None
        if source:
            with Image.open(source) as image:
                image=image.convert('RGBA')
                w,h=image.size
                size=max(w,h)
                if size<32 or size>1024 or size&(size-1):
                    raise ValueError('Expected power-of-two HD sprite canvas: '+str(source))
                if w!=h:
                    padded=Image.new('RGBA',(size,size))
                    padded.alpha_composite(image,((size-w)//2,(size-h)//2))
                    image=padded;w=h=size
                data=texture(name,image)
            changes[name]={'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                           'size':[w,h],'texture_sha256':hashlib.sha256(data).hexdigest()}
        body.append(data)
    if not changes:raise ValueError('No matching radar sprites')
    payload=b''.join(body)
    result=struct.pack('<III',22,len(payload),struct.unpack_from('<I',original,8)[0])+payload
    after=txd_parts(result)
    if [(k,n) for k,n,_ in parts]!=[(k,n) for k,n,_ in after]:
        raise ValueError('Texture dictionary order/count changed')
    if [p for p in parts if p[1] not in changes]!=[p for p in after if p[1] not in changes]:
        raise ValueError('Unrelated HUD textures changed')
    return result,changes

def install(game, assets):
    require_game_closed()
    if game.name!='GTA San Andreas - SA-MP (LuaHZ)':raise ValueError('Use the independent LuaHZ clone')
    target=game/'models/hud.txd';receipt=game/'moonloader/config/native-icons-deploy.json'
    if receipt.exists():raise ValueError('Native icon deployment already exists')
    before=target.read_bytes();result,changes=build(before,assets)
    # The Quickmap pack covers the 62 named native radar sprites, including arrow.
    if len(changes)!=62:raise ValueError('Expected 62 matched sprites, found '+str(len(changes)))
    stamp=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup=game/'Native icon backups'/stamp;backup.mkdir(parents=True)
    (backup/'hud.txd').write_bytes(before)
    temp=target.with_name('hud.txd.luahz-icons.tmp');switched=False
    try:
        with temp.open('xb') as f:f.write(result);f.flush();os.fsync(f.fileno())
        require_game_closed()
        if target.read_bytes()!=before:raise ValueError('Native HUD changed while preparing')
        os.replace(temp,target);switched=True
        if target.read_bytes()!=result:raise ValueError('Native icon verification failed')
        info={'backup':str(backup/'hud.txd'),'original_sha256':hashlib.sha256(before).hexdigest(),
              'new_sha256':hashlib.sha256(result).hexdigest(),'icons':changes,
              'unrelated_hud_textures_unchanged':True,'activation':'Full game restart'}
        receipt.write_text(json.dumps(info,indent=2)+'\n')
        (backup/'deployment.json').write_bytes(receipt.read_bytes())
    except Exception:
        if switched:target.write_bytes(before)
        if temp.exists():temp.unlink()
        if receipt.exists():receipt.unlink()
        raise
    return {'installed_icons':len(changes),'backup':str(backup),'bytes':len(result)}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',required=True,type=Path)
    parser.add_argument('--assets',required=True,type=Path)
    args=parser.parse_args()
    print(json.dumps(install(args.game.resolve(),args.assets.resolve()),indent=2))
