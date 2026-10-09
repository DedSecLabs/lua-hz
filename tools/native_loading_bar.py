#!/usr/bin/env python3
"""Position GTA's live loading bar through local coordinate references.

The original computes X = screen_width/640 * 50, width = screen_width/640 *
180. Use the existing read-only 230 constant for X: (640-180)/2. The footer
update changes Y's bottom-offset reference from 40 to the existing constant
25, aligning the bar center with the credits near 95.5% of screen height.
Keep size, colors, loading percentage, widescreen and shared constants intact.
Supports only the independently verified clean GTA executable.
"""
import argparse
import datetime as dt
import json
from pathlib import Path
import struct
from deploy import require_game_closed
from native_loading import sha,write_atomic

ORIGINAL_SHA='a559aa772fd136379155efa71f00c47aad34bbfeae6196b0fe1047d0645cbd26'
INSTRUCTION_OFFSET=0x5903c8-0x400000-0xc00
BEFORE=bytes.fromhex('d905408b8500')
AFTER=bytes.fromhex('d905808f8500')
OLD_CONSTANT_OFFSET=0x457340
CENTER_CONSTANT_OFFSET=0x457780
WIDTH_CONSTANT_OFFSET=0x459194
Y_INSTRUCTION_OFFSET=0x5903e6-0x400000-0xc00
Y_BEFORE=bytes.fromhex('d80d108a8500')
Y_AFTER=bytes.fromhex('d80de88f8500')
OLD_Y_CONSTANT_OFFSET=0x457210
FOOTER_Y_CONSTANT_OFFSET=0x4577e8

def build(original,footer=False):
    if sha(original)!=ORIGINAL_SHA:raise ValueError('Unsupported GTA executable')
    if original[INSTRUCTION_OFFSET:INSTRUCTION_OFFSET+6]!=BEFORE:
        raise ValueError('Unexpected loading-bar X instruction')
    old=struct.unpack_from('<f',original,OLD_CONSTANT_OFFSET)[0]
    centered=struct.unpack_from('<f',original,CENTER_CONSTANT_OFFSET)[0]
    width=struct.unpack_from('<f',original,WIDTH_CONSTANT_OFFSET)[0]
    if (old,centered,width)!=(50.,230.,180.) or 2*centered+width!=640:
        raise ValueError('Unexpected loading-bar coordinate constants')
    result=original[:INSTRUCTION_OFFSET]+AFTER+original[INSTRUCTION_OFFSET+6:]
    if footer:
        if original[Y_INSTRUCTION_OFFSET:Y_INSTRUCTION_OFFSET+6]!=Y_BEFORE:
            raise ValueError('Unexpected loading-bar Y instruction')
        if (struct.unpack_from('<f',original,OLD_Y_CONSTANT_OFFSET)[0],
            struct.unpack_from('<f',original,FOOTER_Y_CONSTANT_OFFSET)[0])!=(40.,25.):
            raise ValueError('Unexpected loading-bar Y constants')
        result=result[:Y_INSTRUCTION_OFFSET]+Y_AFTER+result[Y_INSTRUCTION_OFFSET+6:]
    return result

def update(game):
    """Keep original recovery files and move the centered bar into the footer."""
    require_game_closed()
    receipt=game/'moonloader/config/loading-bar-deploy.json';previous=receipt.read_bytes()
    info=json.loads(previous);backup=Path(info['backup']);target=game/'gta_sa.exe'
    if backup.resolve().parent!=(game/'Loading screen backups'/'bar').resolve():
        raise ValueError('Unexpected backup path')
    original=(backup/'gta_sa.exe').read_bytes();before=target.read_bytes()
    if sha(original)!=info['original_sha256'] or sha(before)!=info['installed_sha256']:
        raise ValueError('Executable/backup changed; refusing to overwrite')
    after=build(original,footer=True)
    stamp=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    saved=backup/'updates'/stamp;saved.mkdir(parents=True)
    (saved/'gta_sa.exe').write_bytes(before);(saved/'previous-deployment.json').write_bytes(previous)
    info.update(installed_sha256=sha(after),y_instruction_offset=Y_INSTRUCTION_OFFSET,
                original_y_instruction=Y_BEFORE.hex(),installed_y_instruction=Y_AFTER.hex(),
                y_formula='screen_height - screen_height * 25 / 448',
                position='Horizontally centered and vertically aligned with footer credits',
                last_update_backup=str(saved))
    switched=False
    try:
        require_game_closed()
        if target.read_bytes()!=before:raise ValueError('Executable changed during preparation')
        write_atomic(target,after);switched=True
        if target.read_bytes()!=after:raise ValueError('Loading bar verification failed')
        write_atomic(receipt,(json.dumps(info,indent=2)+'\n').encode())
        (saved/'deployment.json').write_bytes(receipt.read_bytes())
    except Exception:
        if switched:write_atomic(target,before)
        write_atomic(receipt,previous)
        raise
    return info

def install(game):
    require_game_closed()
    if game.name!='GTA San Andreas - SA-MP (LuaHZ)':raise ValueError('Use the independent LuaHZ clone')
    target=game/'gta_sa.exe';receipt=game/'moonloader/config/loading-bar-deploy.json'
    if receipt.exists():raise ValueError('Loading bar already centered')
    original=target.read_bytes();after=build(original)
    stamp=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup=game/'Loading screen backups'/'bar'/stamp;backup.mkdir(parents=True)
    (backup/'gta_sa.exe').write_bytes(original)
    info={'backup':str(backup),'original_sha256':sha(original),'installed_sha256':sha(after),
          'instruction_offset':INSTRUCTION_OFFSET,'original_instruction':BEFORE.hex(),
          'installed_instruction':AFTER.hex(),'x_formula':'screen_width * 230 / 640',
          'bar_width_formula':'screen_width * 180 / 640',
          'position':'Horizontally centered; original bottom offset retained',
          'other_executable_bytes_unchanged':True}
    switched=False
    try:
        require_game_closed()
        if target.read_bytes()!=original:raise ValueError('Executable changed during preparation')
        write_atomic(target,after);switched=True
        if target.read_bytes()!=after:raise ValueError('Loading bar verification failed')
        write_atomic(receipt,(json.dumps(info,indent=2)+'\n').encode())
        (backup/'deployment.json').write_bytes(receipt.read_bytes())
    except Exception:
        if switched:write_atomic(target,original)
        if receipt.exists():receipt.unlink()
        raise
    return info

def restore(game):
    require_game_closed()
    receipt=game/'moonloader/config/loading-bar-deploy.json';info=json.loads(receipt.read_text())
    backup=Path(info['backup']);target=game/'gta_sa.exe'
    if backup.resolve().parent!=(game/'Loading screen backups'/'bar').resolve():
        raise ValueError('Unexpected backup path')
    original=(backup/'gta_sa.exe').read_bytes();current=target.read_bytes()
    if sha(original)!=info['original_sha256'] or sha(current)!=info['installed_sha256']:
        raise ValueError('Executable/backup changed; refusing to overwrite')
    write_atomic(target,original)
    try:receipt.rename(backup/'restored-deployment.json')
    except Exception:
        write_atomic(target,current);raise
    return info

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['install','update','restore'])
    p.add_argument('--game',required=True,type=Path);args=p.parse_args()
    print(json.dumps(globals()[args.action](args.game),indent=2))
