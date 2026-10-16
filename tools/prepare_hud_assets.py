#!/usr/bin/env python3
"""Legacy preparation of a bitmap-font atlas from supplied DJDARKO PNG sources.

Current accepted custom HUD fonts use prepare_hud_fonts.py. This older tool is
retained for historical recovery and wanted-star provenance investigation.

Requires Pillow only for asset preparation, not in the game. Originals are read
only; generated third-party images remain in ignored local output.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

PROJECT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source',required=True,type=Path)
args=parser.parse_args()
source=args.source/'PC Version/PNG Source Files'
out=PROJECT/'.local/prepared-hud/hud-v0218'
out.mkdir(parents=True,exist_ok=True)
paths={'pricedown':source/'Pricedown and TW Century (X) (Plain).png',
       'gothic':source/'Bank Gothic and Beckett (1) (Plain).png'}
images={name:Image.open(path).convert('RGBA') for name,path in paths.items()}
dat=args.source/'PC Version/1 Beckett (Plain)/fonts.dat'
lines=[l.split('#')[0].strip()for l in dat.read_text(encoding='cp1252').splitlines()]
lines=[l for l in lines if l];props={};fid=None
for i,line in enumerate(lines):
    if line=='[FONT_ID]':fid=int(lines[i+1])
    if line=='[PROP]':props[fid]=[int(n)for l in lines[i+1:i+27]for n in l.split()]
assert all(len(v)==208 for v in props.values())

def index(ch,kind):
    if ch.isdigit():return 144+int(ch)
    if 'A'<=ch<='Z':return 155+ord(ch)-ord('A')
    if kind=='pricedown':return {'$':93,':':154,'.':207}.get(ch,ord(ch)-32)
    return 91 if ch=='?' else ord(ch)-32

atlas=Image.new('RGBA',(2048,2048))
fonts={};slot=0
for kind,chars,cap_top,cap_height,fid in [
    ('pricedown','0123456789$:-.',64,192,1),
    ('gothic','0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ$%+-/.,:()\'!?',80,156,0)]:
    glyphs={}
    for ch in chars:
        idx=index(ch,kind);x=idx%16*256;y=idx//16*320
        cell=images[kind].crop((x,y,x+256,y+320))
        bbox=cell.getchannel('A').getbbox()
        if not bbox:continue
        if kind=='pricedown':
            # Keep common numeral baseline; colon and period remain shorter.
            glyph=cell.crop((0,cap_top,256,cap_top+cap_height))
        elif ch.isalnum():glyph=cell.crop((0,cap_top,256,cap_top+cap_height))
        else:
            glyph=Image.new('RGBA',(256,cap_height))
            ink=cell.crop(bbox)
            if ch in '-.':
                ink.thumbnail((180,cap_height//4),Image.Resampling.LANCZOS)
                glyph.alpha_composite(ink,(0,cap_height//2 if ch=='-' else cap_height-ink.height))
            else:
                ink.thumbnail((240,cap_height),Image.Resampling.LANCZOS)
                glyph.alpha_composite(ink,(0,(cap_height-ink.height)//2))
        bounds=glyph.getchannel('A').getbbox()
        if not bounds:continue
        ink_width=bounds[2]
        gx=slot%8*256;gy=slot//8*256;slot+=1
        atlas.alpha_composite(glyph,(gx,gy))
        advance=max(props[fid][idx]*8,ink_width+8)
        glyphs[ch]=[gx/2048,gy/2048,(gx+ink_width)/2048,(gy+cap_height)/2048,ink_width,cap_height,advance]
    fonts[kind]={'height':cap_height,'space':cap_height*.35,'glyphs':glyphs}
assert slot<=64
atlas.save(out/'hud-font.png')
# Native five-point star from the supplied plain font sheet, kept as white alpha.
idx=61;x=idx%16*256;y=idx//16*320
cell=images['gothic'].crop((x,y,x+256,y+320))
star=cell.crop(cell.getchannel('A').getbbox());star.save(out/'wanted-star.png')
metadata={'atlas':'hud-v0218/hud-font.png','fonts':fonts}
# Lua data contains geometry/advances only, no third-party executable code.
def lua(value):
    if isinstance(value,dict):return '{'+','.join('['+lua(k)+']='+lua(v)for k,v in value.items())+'}'
    if isinstance(value,list):return '{'+','.join(lua(v)for v in value)+'}'
    if isinstance(value,str):return json.dumps(value)
    return repr(value)
(PROJECT/'src/lib/horizonbase/hud_glyphs.lua').write_text('-- Generated glyph coordinates/advances; see tools/prepare_hud_assets.py.\nreturn '+lua(metadata)+'\n')
manifest={'source':'DJDARKO GTA San Andreas 4K Fonts 2025 v1.0.1','use':'Local development QA',
          'redistribution':'No explicit license in supplied package; public asset packaging review pending',
          'inputs':{p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in [*paths.values(),dat]},
          'atlas_size':[2048,2048],'glyph_count':slot,'wanted_star_index':61,
          'preparation':'Plain bitmap glyphs and spacing data; stock weapon images retained'}
(out/'SOURCE.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'output':str(out),'glyphs':slot,'atlas_bytes':(out/'hud-font.png').stat().st_size,'star_size':star.size}))
