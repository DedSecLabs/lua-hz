#!/usr/bin/env python3
"""Verify an actual temporary clone without private files or the game."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from export_source import ROOT,export

def verify(luajit,toolchain):
    with tempfile.TemporaryDirectory(prefix='luahz-fresh-source-')as directory:
        directory=Path(directory);source=directory/'source';clone=directory/'clone'
        info=export(source)
        quiet={'stdout':subprocess.DEVNULL,'stderr':subprocess.PIPE}
        subprocess.run(['git','init','-q',str(source)],check=True,**quiet)
        subprocess.run(['git','-C',str(source),'add','.'],check=True,**quiet)
        subprocess.run(['git','-C',str(source),'-c','user.name=LuaHZ local verifier','-c','user.email=local-verifier@invalid',
                        'commit','-qm','Temporary source verification snapshot'],check=True,**quiet)
        subprocess.run(['git','clone','-q','--no-hardlinks',str(source),str(clone)],check=True,**quiet)
        assert not (clone/'.local').exists() and not (clone/'branding').exists() and not (clone/'build').exists()
        log=ROOT/'build/fresh-source-verification.log';log.parent.mkdir(exist_ok=True)
        with log.open('w')as output:
            subprocess.run([sys.executable,'tools/check.py','--luajit',str(luajit)],cwd=clone,stdout=output,stderr=subprocess.STDOUT,check=True)
            subprocess.run([sys.executable,'tools/build_native_visuals.py','--toolchain',str(toolchain)],cwd=clone,stdout=output,stderr=subprocess.STDOUT,check=True)
            dependencies=json.loads((clone/'manifests/dependencies.json').read_text())
            fingerprint=dependencies['native_loading_artifact']['resource_fnv32']
            subprocess.run([sys.executable,'tools/build_native_loading.py','--toolchain',str(toolchain),'--asset-fnv',fingerprint],
                           cwd=clone,stdout=output,stderr=subprocess.STDOUT,check=True)
            revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=clone,text=True).strip()
            subprocess.run([sys.executable,'tools/package_release.py','--output','dist/release',
                            '--native-dir','build/native','--revision',revision],
                           cwd=clone,stdout=output,stderr=subprocess.STDOUT,check=True)
        report={'public_source_files':info['file_count'],'real_git_clone':True,'private_files_available':False,
                'offline_checks':'passed','both_native_components':'built','developer_preview_packaging':'passed','game_required':False,
                'log':'build/fresh-source-verification.log','scope':'Code/test/build reproducibility; full cosmetic assets remain external'}
        (ROOT/'build/fresh-source-verification.json').write_text(json.dumps(report,indent=2)+'\n')
        return report

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--luajit',required=True,type=Path);p.add_argument('--toolchain',required=True,type=Path)
    args=p.parse_args();print(json.dumps(verify(args.luajit.resolve(),args.toolchain.resolve()),indent=2))
