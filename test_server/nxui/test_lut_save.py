#!/usr/bin/env python3
"""Regression: click Save on the initially restored LUT without browsing."""
from pathlib import Path
import os, subprocess, tempfile, time
HERE=Path(__file__).resolve().parent
OUT=HERE/'out'
def main():
    rf=Path(os.environ['NXUI_ROOTFS'])
    env=dict(os.environ,DISPLAY=':95',FONTCONFIG_FILE=str(OUT/'fonts-ko.conf'))
    server=subprocess.Popen(['Xvfb',':95','-screen','0','720x480x24','-ac'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try:
        time.sleep(1)
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);calls=root/'calls';log=root/'log'
            (root/'saved-lut').write_text('saved\n')
            (root/'looks').write_text(''.join(f'{k}|{k}|0|0|0|0|0|0|0\n' for k in ['first','saved','third','fourth','fifth','sixth','seventh','eighth']))
            engine=root/'engine';engine.write_text('#!/bin/sh\nprintf "%s %s\\n" "$1" "$2" >> "$NXUI_CALLS"\n')
            env.update(NXUI_STATE_DIR=tmp,NXUI_CALLS=str(calls))
            args=['qemu-arm','-L',str(rf),'-E',f'LD_LIBRARY_PATH={rf}/usr/lib:{rf}/lib',str(OUT/'nxui.arm'),'--live','--lut','--root',tmp,'--engine',str(engine),'--recipes',str(root/'looks'),'--lifetime-ms','10000']
            with log.open('w') as stream:
                proc=subprocess.Popen(args,env=env,stdout=stream,stderr=subprocess.STDOUT)
                try:
                    end=time.monotonic()+8
                    while 'FIRST_FRAME' not in log.read_text() and time.monotonic()<end:
                        time.sleep(.05)
                    assert 'sel=1' in log.read_text(),log.read_text()
                    assert not calls.exists(),'Opening alone must not apply'
                    subprocess.run([str(OUT/'test_input'),'click','272','136','60'],env=env,capture_output=True,timeout=5)
                    try:
                        proc.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        print(log.read_text(),flush=True)
                        raise
                    assert proc.returncode==0,log.read_text()
                    assert calls.exists(),log.read_text()
                    assert calls.read_text()=='apply saved\n',(calls.read_text(),log.read_text())
                    assert 'ok=1' in log.read_text(),log.read_text()
                finally:
                    if proc.poll() is None: proc.kill();proc.wait()
        print('PASS ARM Save button: unchanged restored selection applied exactly once before close')
    finally:
        server.terminate();server.wait(timeout=5)
if __name__=='__main__':main()
