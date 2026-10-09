#!/usr/bin/env python3
"""Replace the splash and correct its square draw area in SAMPFUNCS 5.7.1 R5.

The plugin's RenderSplash hook bypasses GTA's loading dictionaries. Its RCDATA
101 is a reversed/XOR encoded, single-texture TXD. The legacy mode replaces
the fixed DXT1 plane. High-detail mode appends an uncompressed native texture
in a read-only PE section and updates the existing resource leaf/PE sizes;
all original sections, keys, imports and relocation addresses are retained.
A single conditional-jump
opcode becomes an unconditional jump over the plugin's black-fill/square-rect
override, retaining GTA's original full-screen rectangle and balanced stack.
This deliberately supports only the exact, locally verified plugin build.
"""
import argparse
import datetime as dt
import io
import json
from pathlib import Path
import struct
from PIL import Image
from deploy import require_game_closed
from native_loading import sha, write_atomic
from native_radar import txd_parts
from native_fonts import chunk

ORIGINAL_SHA='642fc80f022ef41d9d6c11988de03e3bf32afb4a51b5806f1fecebc4e73c9fb0'
OFFSET=1074848
LENGTH=524456
KEY_OFFSET=790016+(0xddeac-794624)
PIXELS=524288
FIT_OFFSET=1024+(0x1b99c-0x1000)
FIT_BEFORE=b'\x74\x55'
FIT_AFTER=b'\xeb\x55'
HD_WIDTH=2048
HD_HEIGHT=1024
RESOURCE_LEAF=0x106600+0x80

def lossless_txd(artwork):
    """Native format conversion; retain detail without DXT color quantization."""
    with Image.open(artwork) as source:
        image=source.convert('RGBA').resize((HD_WIDTH,HD_HEIGHT),Image.Resampling.LANCZOS)
    pixels=image.tobytes('raw','BGRA')
    native=struct.pack('<I2BH32s32s',9,2,0x11,0,b'_'.ljust(32,b'\0'),bytes(32))
    native+=struct.pack('<IIHHBBBB',0x500,21,HD_WIDTH,HD_HEIGHT,32,1,4,1)
    native+=struct.pack('<I',len(pixels))+pixels
    return chunk(22,chunk(1,struct.pack('<HH',1,2))+chunk(21,chunk(1,native)+chunk(3,b''))+chunk(3,b''))

def hd_resource(data):
    """Validate the appended read-only image section and resource leaf."""
    pe=struct.unpack_from('<I',data,0x3c)[0];optional=pe+24
    count=struct.unpack_from('<H',data,pe+6)[0]
    table=optional+struct.unpack_from('<H',data,pe+20)[0]
    entry=table+(count-1)*40
    name,size,rva,rawsize,offset=struct.unpack_from('<8sIIII',data,entry)
    leaf_rva,leaf_size=struct.unpack_from('<II',data,RESOURCE_LEAF)
    if name!=b'.hzhd\0\0\0' or (rva,size)!=(leaf_rva,leaf_size) or offset+rawsize!=len(data):
        raise ValueError('Unexpected high-detail splash section')
    key=data[KEY_OFFSET:KEY_OFFSET+32]
    txd=decode(data[offset:offset+size],key)
    parts=txd_parts(txd)
    if [(k,n) for k,n,_ in parts]!=[(1,None),(21,'_'),(3,None)]:
        raise ValueError('Unexpected high-detail splash dictionary')
    tex=parts[1][2]
    if struct.unpack_from('<IIHHBBBB',tex,96)!=(0x500,21,HD_WIDTH,HD_HEIGHT,32,1,4,1):
        raise ValueError('Unexpected high-detail splash raster')
    pixels=HD_WIDTH*HD_HEIGHT*4
    if size!=pixels+168 or struct.unpack_from('<I',tex,112)[0]!=pixels:
        raise ValueError('Unexpected high-detail splash payload')
    return {'type':10,'id':101,'language':1033,'offset':offset,'bytes':size,'rva':rva,
            'section':'.hzhd','texture':{'name':'_','width':HD_WIDTH,'height':HD_HEIGHT,
                                       'format':'A8R8G8B8','mips':1}},txd

def build_lossless(original,artwork):
    """Append a larger resource without relocating original sections/code."""
    if sha(original)!=ORIGINAL_SHA or original[FIT_OFFSET:FIT_OFFSET+2]!=FIT_BEFORE:
        raise ValueError('Unsupported original SAMPFUNCS binary')
    pe=struct.unpack_from('<I',original,0x3c)[0];optional=pe+24
    if original[pe:pe+4]!=b'PE\0\0' or struct.unpack_from('<H',original,optional)[0]!=0x10b:
        raise ValueError('Unsupported PE header')
    count=struct.unpack_from('<H',original,pe+6)[0]
    table=optional+struct.unpack_from('<H',original,pe+20)[0];entry=table+count*40
    section_align,file_align=struct.unpack_from('<II',original,optional+32)
    image_size,headers_size=struct.unpack_from('<II',original,optional+56)
    if entry+40>headers_size or any(original[entry:entry+40]):
        raise ValueError('No unused section-header slot')
    if struct.unpack_from('<II',original,RESOURCE_LEAF)!=(0x1410a0,LENGTH):
        raise ValueError('Unexpected original splash resource leaf')
    align=lambda value,unit:(value+unit-1)//unit*unit
    if len(original)%file_align or image_size%section_align:
        raise ValueError('Unexpected PE alignment')
    txd=lossless_txd(artwork);key=original[KEY_OFFSET:KEY_OFFSET+32]
    encoded=encode(txd,key);raw_size=align(len(encoded),file_align)
    data=bytearray(original+encoded+bytes(raw_size-len(encoded)))
    struct.pack_into('<H',data,pe+6,count+1)
    initialized=struct.unpack_from('<I',original,optional+8)[0]
    struct.pack_into('<I',data,optional+8,initialized+raw_size)
    struct.pack_into('<I',data,optional+56,align(image_size+len(encoded),section_align))
    struct.pack_into('<8sIIIIIIHHI',data,entry,b'.hzhd\0\0\0',len(encoded),image_size,
                     raw_size,len(original),0,0,0,0,0x40000040)
    struct.pack_into('<II',data,RESOURCE_LEAF,image_size,len(encoded))
    data[FIT_OFFSET:FIT_OFFSET+2]=FIT_AFTER
    # Only these specific metadata bytes and the verified fit opcode may change.
    normalized=bytearray(data[:len(original)])
    for offset,size in [(pe+6,2),(optional+8,4),(optional+56,4),(entry,40),
                        (RESOURCE_LEAF,8),(FIT_OFFSET,2)]:
        normalized[offset:offset+size]=original[offset:offset+size]
    if bytes(normalized)!=original:raise ValueError('Unrelated plugin bytes changed')
    result=bytes(data)
    if hd_resource(result)[1]!=txd:raise ValueError('HD resource round-trip failed')
    return result

def fit_metadata():
    return {'offset':FIT_OFFSET,'original':FIT_BEFORE.hex(),'installed':FIT_AFTER.hex(),
            'changed_instruction_bytes':1,'behavior':'Preserve GTA full-screen splash rectangle',
            'jump_target_rva':'0x1b9f3'}

def decode(data,key):
    return bytes(value^key[31-i%32]^(i%32)^(i&255) for i,value in enumerate(reversed(data)))

def encode(data,key):
    return bytes(value^key[31-i%32]^(i%32)^(i&255) for i,value in enumerate(data))[::-1]

def raster(txd):
    parts=txd_parts(txd)
    if [(k,n)for k,n,_ in parts]!=[(1,None),(21,'_'),(3,None)]:
        raise ValueError('Unexpected embedded splash dictionary')
    texture=parts[1][2]
    if struct.unpack_from('<IIHHBBBB',texture,96)!=(512,0x31545844,1024,1024,16,1,4,8):
        raise ValueError('Unexpected embedded splash raster')
    if struct.unpack_from('<I',texture,112)[0]!=PIXELS:
        raise ValueError('Unexpected splash payload size')
    # Outer TXD header + dictionary struct chunk + texture header/struct.
    start=12+len(parts[0][2])+116
    if len(txd)!=LENGTH or start+PIXELS+24!=len(txd):
        raise ValueError('Unexpected splash payload boundaries')
    return start

def build(original,artwork):
    if sha(original)!=ORIGINAL_SHA:
        raise ValueError('Unsupported SAMPFUNCS binary; original verified build required')
    if original[FIT_OFFSET:FIT_OFFSET+2]!=FIT_BEFORE:
        raise ValueError('Unexpected splash sizing branch')
    key=original[KEY_OFFSET:KEY_OFFSET+32]
    before=decode(original[OFFSET:OFFSET+LENGTH],key)
    start=raster(before)
    # Native format conversion only. GTA's full-screen draw restores the
    # widescreen proportions after the plugin's square override is bypassed.
    with Image.open(artwork)as image:
        image=image.convert('RGB').resize((1024,1024),Image.Resampling.LANCZOS)
        output=io.BytesIO();image.save(output,format='DDS',pixel_format='DXT1')
    dds=output.getvalue()
    if dds[:4]!=b'DDS ' or dds[84:88]!=b'DXT1' or len(dds)!=128+PIXELS:
        raise ValueError('Invalid DXT1 encoder output')
    after=before[:start]+dds[128:]+before[start+PIXELS:]
    raster(after)
    encrypted=encode(after,key)
    if decode(encrypted,key)!=after:raise ValueError('Splash encoding verification failed')
    result=original[:OFFSET]+encrypted+original[OFFSET+LENGTH:]
    result=result[:FIT_OFFSET]+FIT_AFTER+result[FIT_OFFSET+2:]
    assert len(result)==len(original)
    return result

def install(game,artwork):
    require_game_closed()
    if game.name!='GTA San Andreas - SA-MP (LuaHZ)':raise ValueError('Use the independent LuaHZ clone')
    target=game/'SAMPFUNCS.asi';receipt=game/'moonloader/config/sampfuncs-loading-deploy.json'
    if receipt.exists():raise ValueError('Splash already installed; restore before reinstalling')
    original=target.read_bytes();patched=build(original,artwork)
    stamp=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup=game/'Loading screen backups'/'sampfuncs'/stamp;backup.mkdir(parents=True)
    (backup/'SAMPFUNCS.asi').write_bytes(original)
    info={'backup':str(backup),'artwork':str(artwork),'artwork_sha256':sha(artwork.read_bytes()),
          'original_sha256':sha(original),'installed_sha256':sha(patched),
          'resource':{'type':10,'id':101,'language':1033,'offset':OFFSET,'bytes':LENGTH},
          'texture':{'name':'_','width':1024,'height':1024,'format':'DXT1','mips':1},
          'fullscreen_fit':fit_metadata(),
          'all_bytes_outside_image_and_fit_patch_unchanged':True,
          'activation':'Next full game launch; visual QA by the user'}
    switched=False
    try:
        require_game_closed()
        if target.read_bytes()!=original:raise ValueError('Plugin changed during preparation')
        write_atomic(target,patched)
        switched=True
        if target.read_bytes()!=patched:raise ValueError('Installed splash verification failed')
        write_atomic(receipt,(json.dumps(info,indent=2)+'\n').encode())
        (backup/'deployment.json').write_bytes(receipt.read_bytes())
    except Exception:
        if switched:write_atomic(target,original)
        if receipt.exists():receipt.unlink()
        raise
    return info

def update(game,artwork,lossless=None):
    require_game_closed()
    receipt=game/'moonloader/config/sampfuncs-loading-deploy.json'
    previous=receipt.read_bytes();info=json.loads(previous)
    if lossless is None:
        lossless=info.get('texture',{}).get('format')=='A8R8G8B8'
    backup=Path(info['backup'])
    if backup.resolve().parent!=(game/'Loading screen backups'/'sampfuncs').resolve():
        raise ValueError('Unexpected backup path')
    target=game/'SAMPFUNCS.asi';before=target.read_bytes()
    original=(backup/'SAMPFUNCS.asi').read_bytes()
    if sha(original)!=info['original_sha256'] or sha(before)!=info['installed_sha256']:
        raise ValueError('Plugin/backup changed; refusing to overwrite')
    after=build_lossless(original,artwork) if lossless else build(original,artwork)
    stamp=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    saved=backup/'updates'/stamp;saved.mkdir(parents=True)
    (saved/'SAMPFUNCS.asi').write_bytes(before);(saved/'previous-deployment.json').write_bytes(previous)
    info.pop('all_bytes_outside_image_resource_unchanged',None)
    info.update(installed_sha256=sha(after),artwork=str(artwork),artwork_sha256=sha(artwork.read_bytes()),
                fullscreen_fit=fit_metadata(),all_bytes_outside_image_and_fit_patch_unchanged=True,
                last_update_backup=str(saved))
    if lossless:
        metadata,_=hd_resource(after)
        info.pop('all_bytes_outside_image_and_fit_patch_unchanged',None)
        info.update(resource={k:v for k,v in metadata.items() if k!='texture'},
                    texture=metadata['texture'],original_section_addresses_preserved=True,
                    native_code_changes='Existing full-screen fit opcode only',
                    quality='2048x1024 uncompressed 32-bit color; no DXT compression')
    else:
        for name in ['original_sections_preserved','original_section_addresses_preserved','native_code_changes','quality']:
            info.pop(name,None)
        info.update(resource={'type':10,'id':101,'language':1033,'offset':OFFSET,'bytes':LENGTH},
                    texture={'name':'_','width':1024,'height':1024,'format':'DXT1','mips':1})
    switched=False
    try:
        require_game_closed()
        if target.read_bytes()!=before:raise ValueError('Plugin changed during preparation')
        write_atomic(target,after);switched=True
        if target.read_bytes()!=after:raise ValueError('Installed splash verification failed')
        write_atomic(receipt,(json.dumps(info,indent=2)+'\n').encode())
        (saved/'deployment.json').write_bytes(receipt.read_bytes())
    except Exception:
        if switched:write_atomic(target,before)
        write_atomic(receipt,previous)
        raise
    return info

def restore(game):
    require_game_closed()
    receipt=game/'moonloader/config/sampfuncs-loading-deploy.json'
    info=json.loads(receipt.read_text());target=game/'SAMPFUNCS.asi'
    backup=Path(info['backup'])
    if backup.resolve().parent!=(game/'Loading screen backups'/'sampfuncs').resolve():
        raise ValueError('Unexpected backup path')
    original=(backup/'SAMPFUNCS.asi').read_bytes()
    if sha(original)!=info['original_sha256'] or sha(target.read_bytes())!=info['installed_sha256']:
        raise ValueError('Plugin/backup changed; refusing to overwrite')
    installed=target.read_bytes();write_atomic(target,original)
    try:receipt.rename(backup/'restored-deployment.json')
    except Exception:
        write_atomic(target,installed)
        raise
    return info

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['install','update','restore']);parser.add_argument('--game',type=Path,required=True)
    parser.add_argument('--artwork',type=Path)
    parser.add_argument('--lossless',action='store_true',default=None,help='Upgrade to uncompressed texture; subsequent updates preserve that format automatically')
    args=parser.parse_args()
    if args.action!='restore' and not args.artwork:parser.error('--artwork required')
    if args.lossless and args.action!='update':parser.error('--lossless requires update')
    result=update(args.game,args.artwork,lossless=args.lossless) if args.action=='update' else restore(args.game) if args.action=='restore' else install(args.game,args.artwork)
    print(json.dumps(result,indent=2))
