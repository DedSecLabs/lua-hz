#!/usr/bin/env python3
"""Export audited public source, excluding local inputs/binaries and user state."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[1]
DIRECTORIES={'src','native','tools','tests','assets','docs','manifests','.github'}
FILES={'README.md','AGENTS.md','CONTRIBUTING.md','LICENSE','THIRD_PARTY.md','.gitignore','.gitattributes','requirements-dev.txt'}
APPROVED_BRANDING={
    'assets/branding/luahz-logo.png': '62d16ff2d1dec2a44e6dc75eac91cc66644a12a6a61981c54cc8ccd969a40dc5',
    'assets/branding/luahz-hzheader.png': '62d16ff2d1dec2a44e6dc75eac91cc66644a12a6a61981c54cc8ccd969a40dc5',
    'assets/branding/luahz-hzheader_small.png': 'd154afc36634f7c3463d2d21604dd36a68f1b0577918c7a799a36492ae8e6643',
}
FORBIDDEN_EXTENSIONS={'.dll','.asi','.exe','.txd','.img','.luac','.zip','.pyc','.log'}

def candidates(root=ROOT):
    paths=[]
    ui=root/'assets/ui-v0212';sources=ui/'sources.json'
    licensed=set(json.loads(sources.read_text())) if sources.exists() else set()
    approved={'sources.json','LUCIDE-LICENSE.txt'}|{name+ext for name in licensed for ext in ['.png','.svg']}
    for name in sorted(FILES):
        p=root/name
        if p.is_file():paths.append(p)
    for directory in sorted(DIRECTORIES):
        for p in sorted((root/directory).rglob('*')):
            if not p.is_file() or p.is_symlink() or '__pycache__' in p.parts or p.suffix in FORBIDDEN_EXTENSIONS:continue
            if directory=='assets' and p.relative_to(root).as_posix() in APPROVED_BRANDING:
                if hashlib.sha256(p.read_bytes()).hexdigest()!=APPROVED_BRANDING[p.relative_to(root).as_posix()]:
                    raise ValueError('Approved README logo changed: '+str(p))
                paths.append(p)
                continue
            if directory=='assets' and p.parent!=(root/'assets/ui-v0212'):raise ValueError('Unaudited asset directory: '+str(p))
            if directory=='assets' and (p.name.startswith('radar_') or p.name in {'arrow.png','Jizzy.png','RADAR-ICON-SOURCE.json'}):
                raise ValueError('Unreviewed radar asset in public source: '+str(p))
            if directory=='assets' and p.name not in approved:raise ValueError('Asset not covered by the maintained licensed set: '+str(p))
            paths.append(p)
    return paths

def export(output,root=ROOT):
    if output.exists():raise ValueError('Export destination already exists; preserve it or choose a new destination')
    if output.resolve()==root.resolve():raise ValueError('Cannot export over the project')
    paths=candidates(root)
    for p in paths:
        if p.suffix in {'.md','.json','.py','.lua','.c','.h','.txt','.yml'}:
            text=p.read_text(errors='replace')
            if any(token in text for token in ['/home/'+'amir/','/run/media/'+'amir/','/tmp/'+'codex-clipboard-']):
                raise ValueError('Personal machine path in public file: '+str(p))
    output.mkdir(parents=True)
    hashes={}
    for p in paths:
        relative=p.relative_to(root);target=output/relative;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(p,target);hashes[relative.as_posix()]=hashlib.sha256(target.read_bytes()).hexdigest()
    return {'scope':'Source only; no game files/private art/runtime binaries','files':hashes,'file_count':len(hashes)}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args();info=export(args.output)
    ROOT.joinpath('build').mkdir(exist_ok=True)
    (ROOT/'build/source-export-manifest.json').write_text(json.dumps(info,indent=2)+'\n')
    print(json.dumps({'export':str(args.output),'files':info['file_count'],'scope':info['scope']},indent=2))
