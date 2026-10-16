#!/usr/bin/env python3
"""Prepare accepted HUD font atlases from exact external originals; no deployment.

Requires Pillow for preparation only. Font files remain unchanged. New output
must not exist, so previous prepared assets and owner-tested inputs are retained.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageFont

SCIENCE_GROUP='hud-science-gothic-v042'
PRICEDOWN_GROUP='hud-pricedown-v042'
INPUTS={
    'science_font':'246e4d33a6fcb3846094e5c4c034616f83e9ae10100316df32e2436362deab3d',
    'science_license':'f7f605ce3c63baa5533afdcf02278d604d9f981cf5a3270b021107f65f553c06',
    'pricedown_font':'973c5294ea6e0fe07e58b986b38c0393244bc835cc65889ca9f7b39b8c89ba1e',
    'pricedown_license':'c92ac4471e5d8772a9d0456cfdc9ca5b87eacca41e155e29be4ce3fddbb83fe0',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def lua(value):
    if isinstance(value,dict):
        return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'
    if isinstance(value,list):
        return '{'+','.join(map(lua,value))+'}'
    if isinstance(value,str):
        return json.dumps(value)
    return repr(value)


def render(font_path,kind):
    science=kind=='science_gothic'
    chars=("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ$%+-/.,:()'!?" if science else '0123456789$:-.')
    def face(size):
        font=ImageFont.truetype(str(font_path),size)
        if science:
            font.set_variation_by_axes([0,0,100,500])
        return font
    probe=face(210 if science else 256)
    band_text='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ$%' if science else '0123456789$'
    band=probe.getbbox(band_text,anchor='ls')
    ideal=(210 if science else 256)*(156 if science else 192)/(band[3]-band[1])
    size=round(ideal) if science else math.floor(ideal)
    font=face(size)
    band=font.getbbox(band_text,anchor='ls')
    height=band[3]-band[1]
    dimensions=(2048,2048 if science else 512)
    atlas=Image.new('RGBA',dimensions)
    draw=ImageDraw.Draw(atlas)
    glyphs={}
    for index,ch in enumerate(chars):
        box=font.getbbox(ch,anchor='ls')
        left=min(0,box[0]);width=box[2]-left
        if not 0<width<=248:
            raise ValueError('Unsupported glyph width: '+ch)
        x=index%8*256;y=index//8*256;baseline=y-band[1]
        if science:
            if baseline+box[3]>y+height:
                baseline-=baseline+box[3]-(y+height)
            if baseline+box[1]<y:
                baseline+=y-(baseline+box[1])
        elif box[1]<band[1] or box[3]>band[3]:
            raise ValueError('Pricedown glyph would clip: '+ch)
        draw.text((x-left,baseline),ch,font=font,fill=(255,255,255,255),anchor='ls')
        advance=max(math.ceil(font.getlength(ch)),width)+8
        glyphs[ch]=[x/dimensions[0],y/dimensions[1],(x+width)/dimensions[0],
                    (y+height)/dimensions[1],width,height,advance]
    group=SCIENCE_GROUP if science else PRICEDOWN_GROUP
    return atlas,{'atlas':group+'/font.png','height':height,
                  'space':font.getlength(' ')+8,'glyphs':glyphs},size


def prepare(args):
    for name,expected in INPUTS.items():
        path=getattr(args,name)
        if path.is_symlink() or sha(path.read_bytes())!=expected:
            raise ValueError('Unexpected original font or license: '+name)
    if args.output.exists():
        raise ValueError('Output already exists; preserve it and choose a new directory')
    args.output.mkdir(parents=True)
    records=[]
    for kind,group,font_path,license_path,license_name in [
        ('science_gothic',SCIENCE_GROUP,args.science_font,args.science_license,'OFL.txt'),
        ('pricedown',PRICEDOWN_GROUP,args.pricedown_font,args.pricedown_license,'read_me.html'),
    ]:
        atlas,geometry,size=render(font_path,kind)
        folder=args.output/'resources'/group;folder.mkdir(parents=True)
        atlas.save(folder/'font.png')
        shutil.copy2(license_path,folder/license_name)
        if kind=='science_gothic':
            attribution=('Science Gothic. Copyright 2024 Font Detective LLC. SIL OFL 1.1; no Reserved Font Name.\n'
                         'Design: Thomas Phinney, Vassil Kateliev and Brandon Buerkle.\n'
                         'https://github.com/googlefonts/science-gothic\n'
                         'LuaHZ bitmap adaptation: weight 500, width 100, contrast 0, slant 0.\n')
            source={'name':'Science Gothic','license':'OFL-1.1',
                    'source':'https://github.com/googlefonts/science-gothic',
                    'revision':'6e2b703b3df79fecf04cadc9c54ea68459856e50'}
        else:
            attribution=('Pricedown Regular 3.200 (2004) by Ray Larabie. Copyright 1998 Ray Larabie.\n'
                         'https://www.gta-sanandreas.com/downloads/gtafont.zip\n'
                         'Original Larabie Fonts software-product license is retained in read_me.html.\n'
                         'The original TTF and its alphanumeric designs are unchanged; this is a raster rendering.\n'
                         'Characters use separate advances; original pair kerning is not applied.\n'
                         'The Pricedown bitmap adaptation retains its original name and Larabie license, not LuaHZ MIT.\n')
            source={'name':'Pricedown Regular','version':'3.200 (2004)',
                    'license':'Original Larabie Fonts software-product agreement',
                    'source':'https://www.gta-sanandreas.com/downloads/gtafont.zip',
                    'archive_sha256':'b9e5e5384157e4afac3a3b37f24600590eec1033da7362c27da604f529ed0095'}
        (folder/'ATTRIBUTION.txt').write_text(attribution,encoding='utf-8')
        source.update({'font_sha256':sha(font_path.read_bytes()),
                       'license_sha256':sha(license_path.read_bytes()),
                       'atlas_sha256':sha((folder/'font.png').read_bytes()),
                       'glyph_count':len(geometry['glyphs']),'font_size':size,
                       'modifications':'Fresh bitmap rendering; original font file unmodified; no pair kerning.'})
        (folder/'SOURCE.json').write_text(json.dumps(source,indent=2)+'\n',encoding='utf-8')
        modules=args.output/'modules';modules.mkdir(exist_ok=True)
        (modules/(kind+'_glyphs.lua')).write_text(
            '-- Generated numeric glyph geometry; font notices: docs/licenses/hud-fonts.\nreturn '+lua(geometry)+'\n',encoding='utf-8')
        records.append(source)
    return {'output':str(args.output),'fonts':records,'game_changed':False}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for name in INPUTS:
        parser.add_argument('--'+name.replace('_','-'),type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    print(json.dumps(prepare(parser.parse_args()),indent=2))
