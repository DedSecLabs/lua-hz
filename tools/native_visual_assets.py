#!/usr/bin/env python3
"""Prepare unchanged HZ assets and transactionally restore stock native files.

This prototype consumes verified local deployment receipts; it never downloads
or redistributes third-party assets. Runtime resources remain ignored local QA
output. The five native files are switched only while GTA/SA-MP are closed.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
from deploy import require_game_closed
from native_fonts import chunk
from native_radar import txd_parts,directory

ROOT=Path(__file__).resolve().parents[1]
FILES={'models/fonts.txd','data/fonts.dat','models/hud.txd','models/gta3.img','models/fronten2.txd'}
def sha(path):
    h=hashlib.sha256()
    with path.open('rb')as f:
        while block:=f.read(4*1024*1024):h.update(block)
    return h.hexdigest()
def widths(data):
    lines=[line.split('#')[0].strip()for line in data.decode('cp1252').splitlines()]
    lines=[line for line in lines if line];fonts={};fid=None
    for i,line in enumerate(lines):
        if line=='[FONT_ID]':fid=int(lines[i+1]);fonts[fid]={}
        elif line=='[PROP]':fonts[fid]['prop']=[int(n)for row in lines[i+1:i+27]for n in row.split()]
        elif line=='[UNPROP]':fonts[fid]['unprop']=int(lines[i+1])
        elif line=='[REPLACEMENT_SPACE_CHAR]':fonts[fid]['space']=int(lines[i+1])
    if set(fonts)!={0,1}:raise ValueError('Expected exactly two font tables')
    out=b''
    for i in range(2):
        table=fonts[i]
        if len(table.get('prop',[]))!=208:raise ValueError('Malformed font advances')
        out+=bytes(table['prop']+[table['space'],table['unprop']])
    if len(out)!=420:raise ValueError('Malformed font table size')
    return out
def dictionary(parts):
    selected=list(parts)
    return chunk(22,chunk(1,struct.pack('<HH',len(selected),2))+b''.join(selected)+chunk(3,b''))

def plan(game):
    config=game/'moonloader/config'
    font=json.loads((config/'native-font-deploy.json').read_text())
    icons=json.loads((config/'native-icons-deploy.json').read_text())
    radar=json.loads((config/'native-radar-deploy.json').read_text())
    records={}
    def record(relative,original,old,new=None):
        original=Path(original)
        if not original.resolve().is_relative_to(game.resolve()):raise ValueError('Backup outside game directory')
        if sha(original)!=old:raise ValueError('Original backup changed: '+relative)
        current=sha(game/relative)
        if new and current!=new:raise ValueError('Installed native file changed: '+relative)
        records[relative]={'original':str(original),'original_sha256':old,'current_sha256':current}
    for relative,item in font['files'].items():
        if relative not in {'models/fonts.txd','data/fonts.dat'}:raise ValueError('Unexpected font target')
        record(relative,Path(font['backup'])/relative,item['original_sha256'],item['new_sha256'])
    record('models/hud.txd',icons['backup'],icons['original_sha256'],icons['new_sha256'])
    record('models/gta3.img',radar['backup'],radar['original_sha256'])
    overview=radar['overview']
    record('models/fronten2.txd',overview['backup'],overview['original_sha256'],overview['new_sha256'])
    if set(records)!=FILES:raise ValueError('Incomplete native baseline plan')
    # Validate every replacement and normalize only its directory entry. The
    # complete original archive region must reproduce the stock backup hash.
    raw,entries=directory(game/'models/gta3.img')
    old_raw,old_entries=directory(Path(radar['backup']))
    changes={item['name']:item for item in radar['replaced_entries']}
    if len(changes)!=144 or len(entries)!=len(old_entries):raise ValueError('Unexpected radar replacements')
    normalized=bytearray(raw)
    with (game/'models/gta3.img').open('rb')as f:
        for i,entry in enumerate(entries):
            name,offset,length,archive=entry
            if name in changes:
                item=changes[name]
                if (offset,length,archive)!=(item['offset'],item['sectors'],0):raise ValueError('Radar directory changed')
                f.seek(offset*2048);data=f.read(item['bytes'])
                if hashlib.sha256(data).hexdigest()!=item['sha256']:raise ValueError('Radar tile changed: '+name)
                normalized[i*32:(i+1)*32]=old_raw[i*32:(i+1)*32]
            elif entry!=old_entries[i]:raise ValueError('Unrelated IMG entry changed')
        h=hashlib.sha256();f.seek(0);remaining=radar['original_bytes'];first=bytearray(f.read(min(4*1024*1024,remaining)))
        first[8:8+len(raw)]=normalized;h.update(first);remaining-=len(first)
        while remaining:
            block=f.read(min(4*1024*1024,remaining))
            if not block:raise ValueError('Truncated IMG');
            h.update(block);remaining-=len(block)
        if h.hexdigest()!=radar['original_sha256']:raise ValueError('Original archive payload changed')
    return records,icons,radar

def prepare(game,dll):
    records,icons,radar=plan(game)
    out=ROOT/'.local/prepared-hud/native-v0232';out.mkdir(parents=True,exist_ok=True)
    shutil.copy2(dll,out/'LuaHZVisuals.dll');shutil.copy2(game/'models/fonts.txd',out/'fonts.txd')
    (out/'font-widths.bin').write_bytes(widths((game/'data/fonts.dat').read_bytes()))
    selected=[part for kind,name,part in txd_parts((game/'models/hud.txd').read_bytes())if name in icons['icons']]
    if len(selected)!=len(icons['icons']):raise ValueError('Missing native icon textures')
    (out/'icons.txd').write_bytes(dictionary(selected))
    selected=[part for kind,name,part in txd_parts((game/'models/fronten2.txd').read_bytes())if name=='map']
    if len(selected)!=1:raise ValueError('Missing native overview')
    (out/'overview.txd').write_bytes(dictionary(selected))
    with (game/'models/gta3.img').open('rb')as f:
        for item in radar['replaced_entries']:
            index=int(Path(item['name']).stem[5:]);f.seek(item['offset']*2048);data=f.read(item['bytes'])
            txd_parts(data);(out/f'radar{index:03}.txd').write_bytes(data)
    manifest={'scope':'Local HZ-only native font/icon/map prototype; original asset payloads retained',
              'files':{p.name:sha(p)for p in sorted(out.iterdir())if p.is_file() and p.name!='SOURCE.json'},
              'supported_game':'Verified GTA SA 1.0 US; Windows x86 and Wine',
              'supported_samp_sha256':'b72b5dbe725f81864ca3f78bc7063bda56cc05fc7188af822fa7a754432553a2',
              'asset_note':'Same approved font/icon/map texture bytes; no image regeneration or new compression'}
    (out/'SOURCE.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (ROOT/'.local/native-visual-baseline-plan.json').write_text(json.dumps({'game':str(game),'files':records},indent=2)+'\n')
    return {'resources':str(out),'files':len(manifest['files']),'native_baseline_plan':str(ROOT/'.local/native-visual-baseline-plan.json')}

def switch(game,records):
    require_game_closed()
    if set(records)!=FILES:raise ValueError('Unexpected native target set')
    receipt=game/'moonloader/config/native-visuals-deploy.json'
    if receipt.exists():raise ValueError('Native runtime baseline already installed')
    stamp=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup=game/'Native runtime backups'/stamp;backup.mkdir(parents=True)
    staged={};moved=[];switched=[]
    try:
        for relative,item in records.items():
            target=game/relative;original=Path(item['original'])
            if not original.resolve().is_relative_to(game.resolve()):raise ValueError('Unsafe original backup')
            if sha(target)!=item['current_sha256'] or sha(original)!=item['original_sha256']:
                raise ValueError('Native file/backup changed: '+relative)
            temp=target.with_name(target.name+'.luahz-native-base.tmp')
            with original.open('rb')as src,temp.open('xb')as dst:
                staged[relative]=temp;shutil.copyfileobj(src,dst,4*1024*1024);dst.flush();os.fsync(dst.fileno())
            if sha(temp)!=item['original_sha256']:raise ValueError('Baseline staging failed')
        require_game_closed()
        for relative,item in records.items():
            target=game/relative
            if sha(target)!=item['current_sha256']:raise ValueError('Native file changed during staging')
            saved=backup/relative;saved.parent.mkdir(parents=True,exist_ok=True)
            target.rename(saved);moved.append(relative);staged[relative].rename(target);switched.append(relative)
        info={'backup':str(backup),'files':records,'active_native_files':'Original baseline',
              'runtime_assets':'moonloader/resource/horizonbase/native-v0232',
              'scope':'Fonts, radar icons, streamed map tiles and frontend overview only; loading visuals unchanged'}
        receipt.write_text(json.dumps(info,indent=2)+'\n');(backup/'deployment.json').write_bytes(receipt.read_bytes())
    except Exception:
        for relative in reversed(moved):
            target=game/relative
            if relative in switched:target.unlink()
            (backup/relative).rename(target)
        for temp in staged.values():
            if temp.exists():temp.unlink()
        if receipt.exists():receipt.unlink()
        raise
    return info

def restore(game):
    """Revert this prototype to the preceding global-visual QA installation."""
    require_game_closed()
    receipt=game/'moonloader/config/native-visuals-deploy.json'
    info=json.loads(receipt.read_text());backup=Path(info['backup']);records=info['files']
    if backup.resolve().parent!=(game/'Native runtime backups').resolve() or set(records)!=FILES:
        raise ValueError('Unexpected runtime backup/targets')
    for relative,item in records.items():
        if sha(game/relative)!=item['original_sha256'] or sha(backup/relative)!=item['current_sha256']:
            raise ValueError('Runtime baseline/backup changed: '+relative)
    saved=[];restored=[];disabled=False
    resources=game/'moonloader/resource/horizonbase/native-v0232';disabled_resources=backup/'disabled-native-v0232'
    try:
        require_game_closed()
        for relative in records:
            current=game/relative;stock=backup/'original-baseline'/relative;stock.parent.mkdir(parents=True,exist_ok=True)
            current.rename(stock);saved.append(relative)
            (backup/relative).rename(current);restored.append(relative)
        if resources.exists():resources.rename(disabled_resources);disabled=True
        receipt.rename(backup/'restored-runtime-deployment.json')
    except Exception:
        if disabled:disabled_resources.rename(resources)
        for relative in reversed(saved):
            if relative in restored:(game/relative).rename(backup/relative)
            (backup/'original-baseline'/relative).rename(game/relative)
        raise
    return info

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['prepare','switch','restore']);p.add_argument('--game',required=True,type=Path);p.add_argument('--dll',type=Path)
    args=p.parse_args();game=args.game.resolve()
    if args.action=='prepare':
        if not args.dll:p.error('--dll required for prepare')
        result=prepare(game,args.dll)
    elif args.action=='restore':result=restore(game)
    else:
        info=json.loads((ROOT/'.local/native-visual-baseline-plan.json').read_text())
        if Path(info['game']).resolve()!=game:raise ValueError('Wrong baseline target')
        result=switch(game,info['files'])
    print(json.dumps(result,indent=2))
