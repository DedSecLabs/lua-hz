#!/usr/bin/env python3
"""Run syntax, behavior, interface and deployment checks without launching the game."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

PROJECT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--luajit',required=True,type=Path)
parser.add_argument('--moonloader',type=Path)
args=parser.parse_args()
lj=args.luajit.resolve()
os.chdir(PROJECT)
for path in sorted(Path('src').rglob('*.lua')):
    code='local f,e=loadfile('+json.dumps(str(path))+');assert(f,e)'
    subprocess.run([str(lj),'-e',code],check=True)
print('PASS LuaJIT syntax for all source files',flush=True)
for test in ['server_gate_spec.lua','bootstrap_spec.lua','native_visuals_spec.lua','core_spec.lua','resource_loading_spec.lua','reload_guard_spec.lua','character_spec.lua','native_locations_spec.lua','keys_spec.lua','server_hud_spec.lua','observations_spec.lua','server_info_spec.lua','quick_actions_spec.lua','vehicle_spec.lua','job_actions_spec.lua','bitmap_font_spec.lua','hud_layout_spec.lua','map_icons_spec.lua','gang_zones_spec.lua','ui_spec.lua','startup_spec.lua','openmp_runtime_spec.lua','font_spec.lua']:
    if test=='startup_spec.lua':
        with tempfile.TemporaryDirectory(prefix='luahz-startup-tests-') as directory:
            subprocess.run([str(lj),'tests/'+test,directory],check=True)
    else:
        subprocess.run([str(lj),'tests/'+test],check=True)
with tempfile.TemporaryDirectory(prefix='luahz-catalog-tests-') as directory:
    subprocess.run([str(lj),'tests/location_catalog_spec.lua',directory],check=True)
subprocess.run([sys.executable,'-m','unittest','discover','-s','tests','-p','*_spec.py','-v'],check=True)
if args.moonloader:
    root=args.moonloader.resolve()
    native=(root.parent/'MoonLoader.asi').read_bytes()
    exports={x.decode('ascii') for x in re.findall(rb'[\x20-\x7e]{3,}',native)}
    used=set()
    for path in Path('src').rglob('*.lua'):
        if path.name=='ui_backend.lua':continue
        if '_G.getTimeOfDay' in path.read_text(encoding='utf-8'):used.add('getTimeOfDay')
        used.update(re.findall(r"\b(?:call|Game.call|invoke)\('([^']+)'",path.read_text(encoding='utf-8')))
    missing=used-exports
    if missing:raise SystemExit('Unknown MoonLoader native function names: '+', '.join(sorted(missing)))
    bindings=(root/'lib/mimgui/imgui.lua').read_text(encoding='utf-8')
    backend=(root/'lib/mimgui/init.lua').read_text(encoding='utf-8')
    valid=set(re.findall(r'(?:function )?M\.([A-Za-z0-9_]+)',bindings))|set(re.findall(r'(?:function )?mimgui\.([A-Za-z0-9_]+)',backend))
    valid.update(re.findall(r'function mimgui\.([A-Za-z0-9_]+)',Path('src/lib/horizonbase/ui_backend.lua').read_text(encoding='utf-8')))
    valid|={'new','ImVec2','ImVec4','Col','WindowFlags','Cond','InputTextFlags','FontSource','FontBaseSize'}
    for path in Path('src').rglob('*.lua'):
        if path.name=='ui_backend.lua':continue
        missing=set(re.findall(r'\bim\.([A-Za-z0-9_]+)',path.read_text(encoding='utf-8')))-valid
        if missing:raise SystemExit(str(path)+' uses unknown ImGui API names: '+str(missing))
    events=(root/'lib/samp/events.lua').read_text(encoding='utf-8')
    callbacks=[name for path in Path('src').rglob('*.lua') for name in re.findall(r'function events\.(\w+)',path.read_text(encoding='utf-8'))]
    missing=[name for name in callbacks if "'"+name+"'" not in events]
    if missing:raise SystemExit('Unknown SAMP.Lua event names: '+str(missing))
    print('PASS native and ImGui API names against the installed runtime')
print('All offline checks passed. Live GTA rendering/network behavior still needs gameplay QA.')
