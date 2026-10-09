#!/usr/bin/env python3
"""Build the dependency-free x86 DLL with host GCC and MinGW binutils.

--toolchain points to an installed/extracted MinGW usr directory containing
bin/i686-w64-mingw32-{as,ld} and i686-w64-mingw32/lib/libkernel32.a.
No downloads, compiler installation or game changes occur here.
"""
import argparse
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[1]
def build(toolchain,cc='gcc'):
    out=ROOT/'build/native';out.mkdir(parents=True,exist_ok=True)
    assembly=out/'visuals.s';clean=out/'visuals-pe.s';obj=out/'visuals.o';dll=out/'LuaHZVisuals.dll'
    subprocess.run([cc,'-m32','-std=c11','-Os','-fleading-underscore','-ffreestanding','-fno-builtin',
        '-fno-pic','-fno-pie','-fno-stack-protector','-fno-asynchronous-unwind-tables',
        '-fno-unwind-tables','-fno-ident','-fno-merge-constants','-fno-tree-loop-distribute-patterns',
        '-fno-strict-aliasing','-mno-sse','-Wall','-Wextra','-Werror','-S',str(ROOT/'native/visuals.c'),'-o',str(assembly)],check=True)
    lines=[]
    for line in assembly.read_text().splitlines():
        if re.match(r'\s*\.(type|size|local|section\s+\.note\.GNU-stack)',line):continue
        common=re.match(r'\s*\.comm\s+([^,]+),(\d+),(\d+)',line)
        if common:
            name,size,alignment=common.groups()
            lines.extend(['.bss','.balign '+alignment,name+':','.zero '+size]);continue
        lines.append(line)
    clean.write_text('\n'.join(lines)+'\n')
    subprocess.run([str(toolchain/'bin/i686-w64-mingw32-as'),str(clean),'-o',str(obj)],check=True)
    subprocess.run([str(toolchain/'bin/i686-w64-mingw32-ld'),'-shared','--entry','_DllMain@12',
        '--enable-reloc-section','--no-insert-timestamp','--image-base','0x68000000',
        '-o',str(dll),str(obj),str(ROOT/'native/visuals.def'),
        str(toolchain/'i686-w64-mingw32/lib/libkernel32.a')],check=True)
    return dll

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--toolchain',type=Path,required=True);p.add_argument('--cc',default='gcc')
    args=p.parse_args();print(build(args.toolchain,args.cc))
