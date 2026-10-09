#!/usr/bin/env python3
"""Cache the official open.mp standard skin previews for local character UI QA."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
from io import BytesIO
import json
from pathlib import Path
import re
import urllib.request
from PIL import Image

PROJECT=Path(__file__).resolve().parents[1]
OUT=PROJECT/'.local/prepared-hud/portraits-v0222'
HEADERS={'User-Agent':'Mozilla/5.0','Referer':'https://open.mp/'}
def fetch(url):
    with urllib.request.urlopen(urllib.request.Request(url,headers=HEADERS),timeout=30) as r:
        return r.read(2*1024*1024)
def prepare():
    OUT.mkdir(parents=True,exist_ok=True)
    page=fetch('https://open.mp/docs/scripting/resources/skins').decode()
    urls=sorted(set(re.findall(r'https://assets\.open\.mp/assets/images/skins/\d+\.png',page)))
    if len(urls)<300:raise ValueError('Skin gallery did not contain the expected previews')
    def save(url):
        target=OUT/url.rsplit('/',1)[-1]
        data=target.read_bytes() if target.exists() else fetch(url)
        with Image.open(BytesIO(data)) as image:
            image.verify()
        with Image.open(BytesIO(data)) as image:
            if image.width>1024 or image.height>1024:raise ValueError('Unexpected large portrait')
            size=list(image.size)
        target.write_bytes(data)
        return target.stem,{'url':url,'sha256':hashlib.sha256(data).hexdigest(),'size':size}
    with ThreadPoolExecutor(max_workers=8) as pool:items=dict(pool.map(save,urls))
    (OUT/'SOURCE.json').write_text(json.dumps({'gallery':'https://open.mp/docs/scripting/resources/skins',
        'use':'Local gameplay QA; original preview PNGs','files':items},indent=2)+'\n')
    lua='return {'+','.join('[%s]={%d,%d}'%(key,*value['size']) for key,value in sorted(items.items(),key=lambda item:int(item[0])))+'}\n'
    (PROJECT/'src/lib/horizonbase/skin_portraits.lua').write_text('-- Official open.mp preview dimensions; see tools/prepare_portraits.py.\n'+lua)
    print('Prepared',len(items),'skin portraits in',OUT,flush=True)
if __name__=='__main__':prepare()
