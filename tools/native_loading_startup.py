#!/usr/bin/env python3
"""Install an early endpoint-aware splash gate and restore original binaries."""
import argparse
import datetime as dt
import json
from pathlib import Path
import shutil
from deploy import require_game_closed
from native_visual_assets import sha
from native_loading import write_atomic
import sampfuncs_loading
import native_loading_bar

ROOT=Path(__file__).resolve().parents[1]
def install(game,helper,assets):
    require_game_closed()
    config=game/'moonloader/config';receipt=config/'loading-startup-deploy.json'
    if receipt.exists():raise ValueError('Startup adapter already installed')
    if (game/'LuaHZLoading.asi').exists():raise ValueError('Existing startup helper must be reviewed first')
    sf=json.loads((config/'sampfuncs-loading-deploy.json').read_text())
    bar=json.loads((config/'loading-bar-deploy.json').read_text())
    originals={'SAMPFUNCS.asi':Path(sf['backup'])/'SAMPFUNCS.asi','gta_sa.exe':Path(bar['backup'])/'gta_sa.exe'}
    previous={'SAMPFUNCS.asi':sf['installed_sha256'],'gta_sa.exe':bar['installed_sha256']}
    expected={'SAMPFUNCS.asi':sampfuncs_loading.ORIGINAL_SHA,'gta_sa.exe':native_loading_bar.ORIGINAL_SHA}
    for name,original in originals.items():
        if not original.resolve().is_relative_to((game/'Loading screen backups').resolve()):raise ValueError('Unexpected original backup path')
        if sha(original)!=expected[name] or sha(game/name)!=previous[name]:raise ValueError('Native binary/backup changed: '+name)
    current=(game/'SAMPFUNCS.asi').read_bytes();metadata,decoded=sampfuncs_loading.hd_resource(current)
    encoded=current[metadata['offset']:metadata['offset']+metadata['bytes']]
    if (assets/'loading.enc').read_bytes()!=encoded:raise ValueError('Artwork differs from the approved installed resource')
    if helper.read_bytes()[:2]!=b'MZ':raise ValueError('Missing built startup helper')
    stamp=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup=game/'Loading screen backups/startup'/stamp;backup.mkdir(parents=True)
    resource=game/'moonloader/resource/horizonbase/loading-v0233'
    if resource.exists():raise ValueError('Existing loading resource folder must be reviewed')
    switched=[];resource_added=False;helper_added=False
    try:
        shutil.copytree(assets,resource);resource_added=True
        for name in originals:shutil.copy2(game/name,backup/name)
        for path in [config/'sampfuncs-loading-deploy.json',config/'loading-bar-deploy.json']:
            shutil.copy2(path,backup/path.name)
        require_game_closed()
        for name,original in originals.items():
            if sha(game/name)!=previous[name]:raise ValueError('Binary changed during staging')
            write_atomic(game/name,original.read_bytes());switched.append(name)
            if sha(game/name)!=expected[name]:raise ValueError('Original binary restore failed')
        write_atomic(game/'LuaHZLoading.asi',helper.read_bytes());helper_added=True
        info={'backup':str(backup),'helper_sha256':sha(game/'LuaHZLoading.asi'),
              'original_binaries':expected,'previous_binaries':previous,
              'artwork_sha256':sha(resource/'loading.enc'),'artwork_bytes':len(encoded),
              'texture':metadata['texture'],'quality':'Approved resource bytes retained exactly',
              'activation':'Next full launch; HZ IP/hostname plus port required; other/unknown launches remain stock',
              'user_QA':'Pending HZ/other/HZ loading-screen and bar checks'}
        write_atomic(receipt,(json.dumps(info,indent=2)+'\n').encode());(backup/'deployment.json').write_bytes(receipt.read_bytes())
    except Exception:
        if helper_added:(game/'LuaHZLoading.asi').unlink()
        for name in reversed(switched):write_atomic(game/name,(backup/name).read_bytes())
        if resource_added:shutil.rmtree(resource)
        if receipt.exists():receipt.unlink()
        raise
    return info

def restore(game):
    require_game_closed()
    receipt=game/'moonloader/config/loading-startup-deploy.json';info=json.loads(receipt.read_text())
    backup=Path(info['backup']);resource=game/'moonloader/resource/horizonbase/loading-v0233'
    if backup.resolve().parent!=(game/'Loading screen backups/startup').resolve():raise ValueError('Unexpected startup backup path')
    for name,digest in info['original_binaries'].items():
        if sha(game/name)!=digest or sha(backup/name)!=info['previous_binaries'][name]:raise ValueError('Native binary/backup changed')
    if sha(game/'LuaHZLoading.asi')!=info['helper_sha256'] or sha(resource/'loading.enc')!=info['artwork_sha256']:
        raise ValueError('Startup adapter/resources changed')
    changed=[];moved_helper=False;moved_resource=False
    try:
        require_game_closed()
        for name in info['original_binaries']:
            write_atomic(game/name,(backup/name).read_bytes());changed.append(name)
        (game/'LuaHZLoading.asi').rename(backup/'disabled-LuaHZLoading.asi');moved_helper=True
        resource.rename(backup/'disabled-loading-v0233');moved_resource=True
        receipt.rename(backup/'restored-startup-deployment.json')
    except Exception:
        if moved_resource:(backup/'disabled-loading-v0233').rename(resource)
        if moved_helper:(backup/'disabled-LuaHZLoading.asi').rename(game/'LuaHZLoading.asi')
        for name in changed:
            old_receipt=backup/('sampfuncs-loading-deploy.json' if name=='SAMPFUNCS.asi' else 'loading-bar-deploy.json')
            original=Path(json.loads(old_receipt.read_text())['backup'])/name
            write_atomic(game/name,original.read_bytes())
        raise
    return info

def update(game,helper,assets):
    """Atomically replace the matched helper/artwork pair, preserving baseline."""
    require_game_closed()
    receipt=game/'moonloader/config/loading-startup-deploy.json';previous=receipt.read_bytes();info=json.loads(previous)
    original_backup=Path(info['backup'])
    if original_backup.resolve().parent!=(game/'Loading screen backups/startup').resolve():raise ValueError('Unexpected startup backup')
    resource=game/'moonloader/resource/horizonbase/loading-v0233';target=game/'LuaHZLoading.asi'
    if sha(target)!=info['helper_sha256'] or sha(resource/'loading.enc')!=info['artwork_sha256']:
        raise ValueError('Installed helper/artwork changed; refusing overwrite')
    for name,digest in info['original_binaries'].items():
        if sha(game/name)!=digest:raise ValueError('Original native binary changed')
    if helper.read_bytes()[:2]!=b'MZ' or (assets/'loading.enc').stat().st_size!=8388776:
        raise ValueError('Expected matched helper and uncompressed artwork')
    stamp=dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup=original_backup/'updates'/stamp;backup.mkdir(parents=True)
    (backup/'previous-deployment.json').write_bytes(previous)
    prepared=resource.with_name('loading-v0233-'+stamp+'.tmp');shutil.copytree(assets,prepared)
    before=target.read_bytes();moved=False;switched=False
    try:
        require_game_closed()
        if sha(target)!=info['helper_sha256'] or sha(resource/'loading.enc')!=info['artwork_sha256']:
            raise ValueError('Pair changed during preparation')
        shutil.copy2(target,backup/'LuaHZLoading.asi')
        resource.rename(backup/'loading-v0233');moved=True
        prepared.rename(resource);switched=True
        write_atomic(target,helper.read_bytes())
        info.update(helper_sha256=sha(target),artwork_sha256=sha(resource/'loading.enc'),last_update_backup=str(backup),
                    quality='2048x1024 uncompressed A8R8G8B8; new targeted gang tile',user_QA='New tile pending visual QA; endpoint isolation baseline accepted')
        write_atomic(receipt,(json.dumps(info,indent=2)+'\n').encode());(backup/'deployment.json').write_bytes(receipt.read_bytes())
    except Exception:
        write_atomic(target,before)
        if switched:shutil.rmtree(resource)
        if moved:(backup/'loading-v0233').rename(resource)
        if prepared.exists():shutil.rmtree(prepared)
        write_atomic(receipt,previous)
        raise
    return info

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['install','update','restore']);p.add_argument('--game',required=True,type=Path);p.add_argument('--helper',type=Path);p.add_argument('--assets',type=Path)
    args=p.parse_args()
    if args.action!='restore' and (not args.helper or not args.assets):p.error('--helper and --assets required')
    result=restore(args.game.resolve()) if args.action=='restore' else globals()[args.action](args.game.resolve(),args.helper,args.assets)
    print(json.dumps(result,indent=2))
