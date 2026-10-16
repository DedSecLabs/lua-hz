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
def artwork_fingerprint(asset=None,asset_fingerprint=None):
    if asset is not None:
        data=asset.read_bytes()
        if len(data)!=8388776:raise ValueError('Expected approved uncompressed loading resource')
        fingerprint=fnv(data)
    else:
        if not isinstance(asset_fingerprint,int) or not 0<=asset_fingerprint<=0xffffffff:
            raise ValueError('Provide artwork or its verified 32-bit fingerprint for a source-only build')
        fingerprint=asset_fingerprint
    return fingerprint

def pe_assembly(text):
    """Emit ELF common storage last so it cannot capture initialized data."""
    lines=[];storage=[]
    for line in text.splitlines():
        if re.match(r'\s*\.(type|size|local|section\s+\.note\.GNU-stack)',line):continue
        common=re.match(r'\s*\.comm\s+([^,]+),(\d+),(\d+)',line)
        if common:
            name,size,alignment=common.groups()
            storage+=['.balign '+alignment,name+':','.zero '+size]
        else:lines.append(line)
    if storage:lines+=['.bss']+storage
    return '\n'.join(lines)+'\n'

def build(toolchain,asset=None,cc='gcc',asset_fingerprint=None):
    fingerprint=artwork_fingerprint(asset,asset_fingerprint)
    out=ROOT/'build/native';out.mkdir(parents=True,exist_ok=True)
    asm=out/'loading.s';peasm=out/'loading-pe.s';obj=out/'loading.o';target=out/'LuaHZLoading.asi'
    subprocess.run([cc,'-m32','-std=c11','-Os','-fleading-underscore','-ffreestanding','-fno-builtin',
        '-fno-pic','-fno-pie','-fno-stack-protector','-fno-asynchronous-unwind-tables',
        '-fno-unwind-tables','-fno-ident','-fno-merge-constants','-fno-tree-loop-distribute-patterns',
        '-fno-strict-aliasing','-mno-sse','-Wall','-Wextra','-Werror',
        '-DEXPECTED_SPLASH_FNV='+hex(fingerprint)+'u','-S',str(ROOT/'native/loading.c'),'-o',str(asm)],check=True)
    peasm.write_text(pe_assembly(asm.read_text()))
    subprocess.run([str(toolchain/'bin/i686-w64-mingw32-as'),str(peasm),'-o',str(obj)],check=True)
    subprocess.run([str(toolchain/'bin/i686-w64-mingw32-ld'),'-shared','--entry','_DllMain@12',
        '--enable-reloc-section','--no-insert-timestamp','--image-base','0x69000000',
        '-o',str(target),str(obj),str(ROOT/'native/loading.def'),
        str(toolchain/'i686-w64-mingw32/lib/libkernel32.a')],check=True)
    return target

def build_zig(zig,asset=None,asset_fingerprint=None):
    """Native Windows alternative; same freestanding x86 code and imports."""
    fingerprint=artwork_fingerprint(asset,asset_fingerprint)
    out=ROOT/'build/native';out.mkdir(parents=True,exist_ok=True)
    target=out/'LuaHZLoading.asi'
    subprocess.run([str(zig),'cc','-target','x86-windows-gnu','-Os','-std=c11',
        '-ffreestanding','-fno-builtin','-fno-stack-protector','-fno-strict-aliasing','-mno-sse',
        '-DEXPECTED_SPLASH_FNV='+hex(fingerprint)+'u','-nostdlib','-shared',
        str(ROOT/'native/loading.c'),str(ROOT/'native/loading.def'),'-lkernel32',
        '-Wl,--entry,DllMain@12,--image-base,0x69000000','-o',str(target)],check=True)
    return target
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    compiler=p.add_mutually_exclusive_group(required=True)
    compiler.add_argument('--toolchain',type=Path);compiler.add_argument('--zig',type=Path)
    source=p.add_mutually_exclusive_group(required=True);source.add_argument('--asset',type=Path);source.add_argument('--asset-fnv',type=lambda text:int(text,0))
    p.add_argument('--cc',default='gcc')
    args=p.parse_args()
    print(build_zig(args.zig,args.asset,args.asset_fnv) if args.zig else build(args.toolchain,args.asset,args.cc,args.asset_fnv))
