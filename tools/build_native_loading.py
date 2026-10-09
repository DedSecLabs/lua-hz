#!/usr/bin/env python3
"""Build the early loading-screen checker using the verified local artwork."""
import argparse
from pathlib import Path
import re
import subprocess
ROOT=Path(__file__).resolve().parents[1]
def fnv(data):
    value=2166136261
    for byte in data:value=((value^byte)*16777619)&0xffffffff
    return value
def build(toolchain,asset=None,cc='gcc',asset_fingerprint=None):
    if asset is not None:
        data=asset.read_bytes()
        if len(data)!=8388776:raise ValueError('Expected approved uncompressed loading resource')
        fingerprint=fnv(data)
    else:
        if not isinstance(asset_fingerprint,int) or not 0<=asset_fingerprint<=0xffffffff:
            raise ValueError('Provide artwork or its verified 32-bit fingerprint for a source-only build')
        fingerprint=asset_fingerprint
    out=ROOT/'build/native';out.mkdir(parents=True,exist_ok=True)
    asm=out/'loading.s';peasm=out/'loading-pe.s';obj=out/'loading.o';target=out/'LuaHZLoading.asi'
    subprocess.run([cc,'-m32','-std=c11','-Os','-fleading-underscore','-ffreestanding','-fno-builtin',
        '-fno-pic','-fno-pie','-fno-stack-protector','-fno-asynchronous-unwind-tables',
        '-fno-unwind-tables','-fno-ident','-fno-merge-constants','-fno-tree-loop-distribute-patterns',
        '-fno-strict-aliasing','-mno-sse','-Wall','-Wextra','-Werror',
        '-DEXPECTED_SPLASH_FNV='+hex(fingerprint)+'u','-S',str(ROOT/'native/loading.c'),'-o',str(asm)],check=True)
    lines=[]
    for line in asm.read_text().splitlines():
        if re.match(r'\s*\.(type|size|local|section\s+\.note\.GNU-stack)',line):continue
        common=re.match(r'\s*\.comm\s+([^,]+),(\d+),(\d+)',line)
        if common:
            name,size,alignment=common.groups();lines+=['.bss','.balign '+alignment,name+':','.zero '+size]
        else:lines.append(line)
    peasm.write_text('\n'.join(lines)+'\n')
    subprocess.run([str(toolchain/'bin/i686-w64-mingw32-as'),str(peasm),'-o',str(obj)],check=True)
    subprocess.run([str(toolchain/'bin/i686-w64-mingw32-ld'),'-shared','--entry','_DllMain@12',
        '--enable-reloc-section','--no-insert-timestamp','--image-base','0x69000000',
        '-o',str(target),str(obj),str(ROOT/'native/loading.def'),
        str(toolchain/'i686-w64-mingw32/lib/libkernel32.a')],check=True)
    return target
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--toolchain',required=True,type=Path)
    source=p.add_mutually_exclusive_group(required=True);source.add_argument('--asset',type=Path);source.add_argument('--asset-fnv',type=lambda text:int(text,0))
    p.add_argument('--cc',default='gcc')
    args=p.parse_args();print(build(args.toolchain,args.asset,args.cc,args.asset_fnv))
