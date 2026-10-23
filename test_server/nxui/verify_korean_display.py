#!/usr/bin/env python3
"""Render Korean NXUI with the camera libraries under QEMU and Xvfb.
Requires a Linux build environment with qemu-arm, Xvfb and NXUI_ROOTFS.
No camera is connected and no camera commands are executed.
"""
from pathlib import Path
import json
import os
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE / 'out'
RF = Path(os.environ['NXUI_ROOTFS'])

def main():
    data = json.loads((ROOT / 'scripts/filmlab/recipes.json').read_text())
    fields = ('R_COLOR','G_COLOR','B_COLOR','HUE','SATURATION','SHARPNESS','CONTRAST')
    recipes = OUT / 'recipes.txt'
    recipes.write_text(''.join('|'.join([k,r['label']]+[str(r[f]) for f in fields])+'\n' for k,r in data['recipes'].items()))
    looks = OUT / 'looks-ko.txt'
    looks.write_text(''.join(f'look{i}|한글 필터 {i}|0|0|0|0|0|0|0\n' for i in range(8)))
    conf = OUT / 'fonts-ko.conf'
    conf.write_text(f'<fontconfig><dir>{ROOT}/scripts/nxui/fonts-ko</dir><cachedir>/tmp/metol-font-cache</cachedir></fontconfig>')
    env = dict(os.environ, DISPLAY=':97', LC_ALL='C', FONTCONFIG_FILE=str(conf))
    server = subprocess.Popen(['Xvfb',':97','-screen','0','720x480x24','-nolisten','tcp','-ac'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    records = []
    try:
        time.sleep(1)
        assert server.poll() is None
        prefix = ['qemu-arm','-L',str(RF),'-E',f'LD_LIBRARY_PATH={RF}/usr/lib:{RF}/lib',str(OUT/'nxui.arm')]
        for mode in ['menu','filmlab','lut']:
            shot = OUT / f'ko-arm-{mode}.ppm'
            args = prefix+['--dry-run','--root',str(ROOT/'scripts'),'--recipes',str(looks if mode=='lut' else recipes),'--snapshot',str(shot)]
            if mode=='menu': args += ['--menu','gui_ini.NX500']
            if mode=='lut': args += ['--lut']
            run = subprocess.run(args,env=env,capture_output=True,timeout=30)
            log = run.stdout+run.stderr
            (OUT/f'ko-arm-{mode}.log').write_bytes(log)
            assert run.returncode==0,log.decode(errors='replace')
            header,shape,depth,pixels=shot.read_bytes().split(b'\n',3)
            assert header==b'P6' and shape==(b'720 336' if mode=='menu' else b'720 208')
            assert len(set(pixels))>12
            assert b'FONT tier2=' not in log,log.decode(errors='replace')
            records.append({'mode':mode,'result':'PASS','size':shape.decode()})
        (OUT/'korean-display-results.json').write_text(json.dumps(records,indent=2))
        print(json.dumps(records,indent=2))
    finally:
        server.terminate()
        server.wait(timeout=5)

if __name__=='__main__': main()
