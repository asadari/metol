#!/usr/bin/env python3
"""Verify persisted LUT selection with the ARM binary under QEMU/Xvfb."""
import os
from pathlib import Path
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]

def main():
    rf = Path(os.environ['NXUI_ROOTFS'])
    with tempfile.TemporaryDirectory() as tmp:
        state = Path(tmp)
        recipes = state/'looks.txt'
        recipes.write_text(''.join(f'{key}|{key}|0|0|0|0|0|0|0\n' for key in ['first','saved','last']))
        (state/'saved-lut').write_text('saved\n')
        (state/'last-lut').write_text('last\n')
        env = dict(os.environ, DISPLAY=':96', NXUI_STATE_DIR=tmp, FONTCONFIG_FILE=str(HERE/'out/fonts-ko.conf'))
        server = subprocess.Popen(['Xvfb', ':96', '-screen','0','720x480x24','-ac'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            time.sleep(1)
            def check(index):
                args = ['qemu-arm','-L',str(rf),'-E',f'LD_LIBRARY_PATH={rf}/usr/lib:{rf}/lib',str(HERE/'out/nxui.arm'),'--root',str(ROOT/'scripts'),'--recipes',str(recipes),'--lut','--dry-run','--lifetime-ms','200']
                result = subprocess.run(args,env=env,capture_output=True,text=True,timeout=15)
                assert result.returncode == 0, result.stderr
                assert f'sel={index}' in result.stderr+result.stdout, result.stderr+result.stdout
                assert (state/'last-lut').read_text()=='last\n'
            check(1)
            recipes.write_text('saved|saved|0|0|0|0|0|0|0\nfirst|first|0|0|0|0|0|0|0\n')
            check(0)
            (state/'saved-lut').write_text('missing\n')
            check(0)
            (state/'saved-lut').unlink()
            recipes.write_text('first|first|0|0|0|0|0|0|0\nlast|last|0|0|0|0|0|0|0\n')
            check(1)
        finally:
            server.terminate();server.wait(timeout=5)
    print('PASS ARM LUT selection: saved preference, reordered list, missing file, legacy fallback, no exit overwrite')

if __name__ == '__main__': main()
